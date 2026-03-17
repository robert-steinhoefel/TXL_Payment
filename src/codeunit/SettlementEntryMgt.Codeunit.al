namespace P3.TXL.Payment.Settlement;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.Dimension;
using Microsoft.Bank.Ledger;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Receivables;
using Microsoft.Sales.History;
using Microsoft.Finance.GeneralLedger.Account;

/// <summary>
/// Settlement Entry Mgt. (Codeunit 51106)
/// Creates and manages Settlement Entries for the cameralistic payment allocation model.
///
/// Epics covered:
///   Epic 2 — Full Settlement (payment = invoice): CreateSalesSettlementEntries
///   Epic 3 — Partial Payments: extend CreateSalesSettlementEntries (remove full-settlement guard)
///   Epic 5 — Reversals + Credit Memos: add CreateReversalEntries
///   Epic 9 — Purchase Area: add CreatePurchSettlementEntries (mirrors sales logic)
///
/// Called from:
///   EventSubscriber.OnAfterInsertDetailedCustomerLedgerEntry (sales)
///   EventSubscriber.OnAfterInsertDetailedVendorLedgerEntry   (purchase, Epic 9)
/// </summary>
codeunit 51106 "Settlement Entry Mgt."
{
    Permissions =
        tabledata "Settlement Entry" = ri,
        tabledata "Sales Invoice Line" = rm,
        tabledata "Cust. Ledger Entry" = r,
        tabledata "Bank Account Ledger Entry" = r,
        tabledata "General Ledger Setup" = r,
        tabledata "Dimension Set Entry" = r,
        tabledata Customer = r,
        tabledata "G/L Account" = r;

    // ── Public entry points ──────────────────────────────────────────────────

    /// <summary>
    /// Called from EventSubscriber.OnAfterInsertDetailedCustomerLedgerEntry (invoice-side DCLE).
    /// InvoiceCLE is the customer invoice CLE that was just closed by a payment.
    /// BC sets "Remaining Amount", "Closed by Entry No.", and "Pmt. Disc. Given (LCY)"
    /// on the CLE before inserting Application DCLEs — all fields are reliable at this point.
    /// Exits silently for partial payments (Epic 3) and credit memo applications (Epic 5).
    /// </summary>
    procedure CreateSalesSettlementEntries(InvoiceCLE: Record "Cust. Ledger Entry"; PostingDate: Date)
    begin
        if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::Invoice then
            exit;
        ProcessInvoiceCLEForSettlement(InvoiceCLE, PostingDate);
    end;

    // ── Private: per-invoice processing ─────────────────────────────────────

    local procedure ProcessInvoiceCLEForSettlement(InvoiceCLE: Record "Cust. Ledger Entry"; PostingDate: Date)
    var
        PaymentCLE: Record "Cust. Ledger Entry";
        SalesInvLine: Record "Sales Invoice Line";
        BankLedgEntry: Record "Bank Account Ledger Entry";
        AssignmentID: Code[50];
        PaymentAmtLCY: Decimal;
        CashDiscountAmtLCY: Decimal;
        TotalAmtExclVAT: Decimal;
        TotalAmtInclVAT: Decimal;
        TotalLines: Integer;
    begin
        // ── Guard: only fully-settled invoices (partial payments → Epic 3) ──
        if InvoiceCLE."Remaining Amount" <> 0 then
            exit;

        // ── Guard: Invoice document type only ───────────────────────────────
        if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::Invoice then
            exit;

        // ── Guard: settled by a payment, not a credit memo (→ Epic 5) ───────
        if not IsSettledByPayment(InvoiceCLE) then
            exit;

        // ── Collect invoice line totals for proportional distribution ────────
        SalesInvLine.SetRange("Document No.", InvoiceCLE."Document No.");
        SalesInvLine.SetFilter(Amount, '<>0');
        TotalLines := SalesInvLine.Count();
        if TotalLines = 0 then
            exit;

        if SalesInvLine.FindSet() then
            repeat
                TotalAmtExclVAT += SalesInvLine.Amount;
                TotalAmtInclVAT += SalesInvLine."Amount Including VAT";
            until SalesInvLine.Next() = 0;

        if TotalAmtInclVAT = 0 then
            exit;

        // ── Amounts ─────────────────────────────────────────────────────────
        // Actual cash received: Payment CLE "Original Amount" is negative (credit to AR) → negate.
        PaymentCLE.Get(InvoiceCLE."Closed by Entry No.");
        PaymentAmtLCY := -PaymentCLE."Original Amount";

        // Story 2.2: BC sets "Pmt. Disc. Given (LCY)" on the invoice CLE before inserting
        // Application DCLEs — available without DCLE ordering issues.
        CashDiscountAmtLCY := GetCashDiscountAmt(InvoiceCLE);

        // ── Context for all Settlement Entries in this application ───────────
        BankLedgEntry := GetBankLedgEntryForPayment(InvoiceCLE);
        AssignmentID := GenerateAssignmentID(InvoiceCLE."Customer No.", PostingDate);

        // ── Create one Settlement Entry per non-zero invoice line ────────────
        SalesInvLine.FindSet(); // Reset cursor — filters are preserved from above
        CreateSalesLineEntries(
            SalesInvLine, TotalLines, InvoiceCLE, PostingDate, BankLedgEntry,
            TotalAmtExclVAT, TotalAmtInclVAT,
            PaymentAmtLCY, CashDiscountAmtLCY, AssignmentID);
    end;

    // ── Private: application type detection ─────────────────────────────────

    local procedure IsSettledByPayment(var InvoiceCLE: Record "Cust. Ledger Entry"): Boolean
    var
        ClosingCLE: Record "Cust. Ledger Entry";
    begin
        // BC sets "Closed by Entry No." on the invoice CLE *before* inserting Application DCLEs,
        // so this field is reliable even when the payment-side DCLE has not yet been inserted.
        // For credit memo settlements "Closed by Entry No." points to the credit memo CLE
        // (Document Type = Credit Memo) → returns false → handled in Epic 5.
        if InvoiceCLE."Closed by Entry No." = 0 then
            exit(false);
        if not ClosingCLE.Get(InvoiceCLE."Closed by Entry No.") then
            exit(false);
        exit(ClosingCLE."Document Type" in
            ["Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund]);
    end;

    // ── Private: amount helpers ──────────────────────────────────────────────

    /// <summary>
    /// Returns the cash discount amount (positive, LCY) granted in this application.
    /// "Pmt. Disc. Given (LCY)" is set by BC on the invoice CLE before Application DCLEs are
    /// inserted, so it is reliably available at OnAfterInsertDetailedCustomerLedgerEntry time.
    /// </summary>
    local procedure GetCashDiscountAmt(var InvoiceCLE: Record "Cust. Ledger Entry"): Decimal
    begin
        // BC stores "Pmt. Disc. Given (LCY)" as a negative amount (reduces AR) → negate for positive discount.
        exit(-InvoiceCLE."Pmt. Disc. Given (LCY)");
    end;

    // ── Private: bank ledger entry lookup ────────────────────────────────────

    /// <summary>
    /// Returns the Bank Account Ledger Entry linked to the payment that settled this invoice.
    /// Returns an empty record if the payment was not posted via a bank account
    /// (e.g. direct customer account journals), in which case Bank Statement Document No. stays blank.
    /// </summary>
    local procedure GetBankLedgEntryForPayment(var InvoiceCLE: Record "Cust. Ledger Entry"): Record "Bank Account Ledger Entry"
    var
        PaymentCLE: Record "Cust. Ledger Entry";
        BankLedgEntry: Record "Bank Account Ledger Entry";
    begin
        if InvoiceCLE."Closed by Entry No." = 0 then
            exit(BankLedgEntry);
        if not PaymentCLE.Get(InvoiceCLE."Closed by Entry No.") then
            exit(BankLedgEntry);

        BankLedgEntry.SetRange("Transaction No.", PaymentCLE."Transaction No.");
        BankLedgEntry.SetRange("Posting Date", PaymentCLE."Posting Date");
        if BankLedgEntry.FindFirst() then
            exit(BankLedgEntry);

        Clear(BankLedgEntry);
        exit(BankLedgEntry);
    end;

    // ── Private: Assignment ID generation ───────────────────────────────────

    /// <summary>
    /// Generates a unique Assignment ID for the current application event.
    /// Format: {CVNo}-{YYMMDD}-{SeqNo}  e.g. CUST001-260316-1
    /// All Settlement Entries created in one application event share the same Assignment ID,
    /// enabling Power BI to aggregate by payment / invoice / assignment.
    /// SeqNo increments if the same customer already has assignments on this date.
    /// </summary>
    local procedure GenerateAssignmentID(CVNo: Code[20]; SettlementDate: Date): Code[50]
    var
        ExistingEntry: Record "Settlement Entry";
        DatePart: Text[6];
        Prefix: Text;
        SeqStr: Text;
        CurSeq: Integer;
        MaxSeq: Integer;
    begin
        DatePart := Format(SettlementDate, 0, '<Year,2><Month,2><Day,2>');
        Prefix := CVNo + '-' + DatePart + '-';

        // Find the highest sequence number used so far for this CV + date.
        // Within the current transaction, already-inserted (but uncommitted) entries are visible.
        ExistingEntry.SetRange("CV No.", CVNo);
        ExistingEntry.SetRange("Settlement Date", SettlementDate);
        if ExistingEntry.FindSet() then
            repeat
                if StrLen(ExistingEntry."Assignment ID") > StrLen(Prefix) then begin
                    SeqStr := CopyStr(ExistingEntry."Assignment ID", StrLen(Prefix) + 1);
                    if Evaluate(CurSeq, SeqStr) then
                        if CurSeq > MaxSeq then
                            MaxSeq := CurSeq;
                end;
            until ExistingEntry.Next() = 0;

        exit(CopyStr(Prefix + Format(MaxSeq + 1), 1, 50));
    end;

    // ── Private: line entry creation ─────────────────────────────────────────

    local procedure CreateSalesLineEntries(
        var SalesInvLine: Record "Sales Invoice Line";
        TotalLines: Integer;
        InvoiceCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        TotalAmtExclVAT: Decimal;
        TotalAmtInclVAT: Decimal;
        PaymentAmtLCY: Decimal;
        CashDiscountAmtLCY: Decimal;
        AssignmentID: Code[50])
    var
        Customer: Record Customer;
        LineCount: Integer;
        // Rounding-correct distribution: initialize remaining to the total and
        // assign the remainder to the last line, so Sum(lines) = target exactly.
        //   Settlement Amt (LCY):         excl. VAT equivalent of PaymentAmtLCY
        //   Settlement Amt Incl. VAT:     actual cash received proportionally
        //   Cash Discount Amt (LCY):      excl. VAT equivalent of CashDiscountAmtLCY
        // For full settlement without discount: Settlement Amt = Line.Amount, Discount = 0.
        // For full settlement with discount:    Settlement Amt + Discount = Line.Amount.
        RemainingAmt: Decimal;
        RemainingAmtInclVAT: Decimal;
        RemainingDiscount: Decimal;
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
        LineDiscount: Decimal;
    begin
        Customer.Get(InvoiceCLE."Customer No.");

        // Totals to distribute across lines (rounding is absorbed by the last line)
        RemainingAmt := Round(PaymentAmtLCY * TotalAmtExclVAT / TotalAmtInclVAT);
        RemainingAmtInclVAT := PaymentAmtLCY;
        RemainingDiscount := Round(CashDiscountAmtLCY * TotalAmtExclVAT / TotalAmtInclVAT);

        repeat
            LineCount += 1;

            if LineCount = TotalLines then begin
                // Last line: absorb all rounding differences
                LineAmt := RemainingAmt;
                LineAmtInclVAT := RemainingAmtInclVAT;
                LineDiscount := RemainingDiscount;
            end else begin
                // Proportional distribution
                // Denominator is TotalAmtInclVAT for both fields so that
                //   Settlement Amt (LCY) + Cash Discount Amt (LCY) = Line.Amount  (full settlement)
                LineAmt := Round(SalesInvLine.Amount * PaymentAmtLCY / TotalAmtInclVAT);
                LineAmtInclVAT := Round(SalesInvLine."Amount Including VAT" * PaymentAmtLCY / TotalAmtInclVAT);
                LineDiscount := Round(SalesInvLine.Amount * CashDiscountAmtLCY / TotalAmtInclVAT);
                RemainingAmt -= LineAmt;
                RemainingAmtInclVAT -= LineAmtInclVAT;
                RemainingDiscount -= LineDiscount;
            end;

            // Insert via a dedicated procedure so that SettlementEntry is a fresh local
            // variable on every call — Init() does NOT reset AutoIncrement fields, so
            // reusing the same record variable across loop iterations causes
            // "Entry No. N already exists" on the second Insert.
            InsertSalesSettlementEntry(
                SalesInvLine, InvoiceCLE, PostingDate, BankLedgEntry, Customer,
                AssignmentID, LineAmt, LineAmtInclVAT, LineDiscount);

            // Update stored Outstanding Amount on the invoice line
            UpdateSalesInvLineOutstandingAmt(SalesInvLine);

        until SalesInvLine.Next() = 0;
    end;

    local procedure InsertSalesSettlementEntry(
        var SalesInvLine: Record "Sales Invoice Line";
        InvoiceCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        Customer: Record Customer;
        AssignmentID: Code[50];
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
        LineDiscount: Decimal)
    var
        // Fresh local variable on every call: Entry No. is always 0 before Insert,
        // so AutoIncrement can assign the next available number without collision.
        SettlementEntry: Record "Settlement Entry";
        GLAccount: Record "G/L Account";
    begin
        SettlementEntry.Init();

        // Source classification
        SettlementEntry."Transaction Type" := "Settlement Transaction Type"::Sales;
        SettlementEntry."Document Type" := "Gen. Journal Document Type"::Invoice;
        SettlementEntry."Document No." := SalesInvLine."Document No.";
        SettlementEntry."Document Line No." := SalesInvLine."Line No.";

        // Assignment & Settlement amounts
        SettlementEntry."Assignment ID" := AssignmentID;
        SettlementEntry."Settlement Date" := PostingDate;
        SettlementEntry."Settlement Amt (LCY)" := LineAmt;
        SettlementEntry."Settlement Amt Incl. VAT (LCY)" := LineAmtInclVAT;
        SettlementEntry."Cash Discount Amt (LCY)" := LineDiscount;

        // Original line amounts — snapshot for reporting comparison
        SettlementEntry."Original Line Amt (LCY)" := SalesInvLine.Amount;
        SettlementEntry."Orig. Line Amt Incl. VAT (LCY)" := SalesInvLine."Amount Including VAT";
        // "Non-Deductible VAT Amt (LCY)" not populated in Epic 2 —
        // requires Non-Deductible VAT feature to be active (BC 22+); deferred.

        // Bank reference (blank when payment not posted via bank account)
        SettlementEntry."Bank Statement Document No." := BankLedgEntry."Document No.";

        // CV — snapshot: name is stored at creation time and does not update on rename
        SettlementEntry."CV No." := InvoiceCLE."Customer No.";
        SettlementEntry."CV Name" := Customer.Name;

        // Dimensions — carried over from invoice line
        SettlementEntry."Global Dimension 1 Code" := SalesInvLine."Shortcut Dimension 1 Code";
        SettlementEntry."Global Dimension 2 Code" := SalesInvLine."Shortcut Dimension 2 Code";
        SettlementEntry."Dimension Set ID" := SalesInvLine."Dimension Set ID";
        PopulateShortcutDimensions(SettlementEntry, SalesInvLine."Dimension Set ID");

        // G/L Account — only available when line type is G/L Account;
        // Item/Resource lines require posting group lookup (deferred)
        if SalesInvLine.Type = SalesInvLine.Type::"G/L Account" then begin
            SettlementEntry."G/L Account No." := SalesInvLine."No.";
            if GLAccount.Get(SalesInvLine."No.") then
                SettlementEntry."G/L Account Name" := GLAccount.Name;
        end;

        // Description
        SettlementEntry.Description :=
            CopyStr(SalesInvLine.Description, 1, MaxStrLen(SettlementEntry.Description));

        // Audit
        SettlementEntry."Created By" :=
            CopyStr(UserId(), 1, MaxStrLen(SettlementEntry."Created By"));
        SettlementEntry."Created DateTime" := CurrentDateTime();

        SettlementEntry.Insert(true);
    end;

    // ── Private: dimension helpers ───────────────────────────────────────────

    local procedure PopulateShortcutDimensions(var SettlementEntry: Record "Settlement Entry"; DimensionSetID: Integer)
    var
        DimSetEntry: Record "Dimension Set Entry";
        GLSetup: Record "General Ledger Setup";
    begin
        if DimensionSetID = 0 then
            exit;

        GLSetup.Get();
        DimSetEntry.SetRange("Dimension Set ID", DimensionSetID);
        if not DimSetEntry.FindSet() then
            exit;

        repeat
            case DimSetEntry."Dimension Code" of
                GLSetup."Shortcut Dimension 3 Code":
                    SettlementEntry."Shortcut Dimension 3 Code" := DimSetEntry."Dimension Value Code";
                GLSetup."Shortcut Dimension 4 Code":
                    SettlementEntry."Shortcut Dimension 4 Code" := DimSetEntry."Dimension Value Code";
                GLSetup."Shortcut Dimension 5 Code":
                    SettlementEntry."Shortcut Dimension 5 Code" := DimSetEntry."Dimension Value Code";
                GLSetup."Shortcut Dimension 6 Code":
                    SettlementEntry."Shortcut Dimension 6 Code" := DimSetEntry."Dimension Value Code";
                GLSetup."Shortcut Dimension 7 Code":
                    SettlementEntry."Shortcut Dimension 7 Code" := DimSetEntry."Dimension Value Code";
                GLSetup."Shortcut Dimension 8 Code":
                    SettlementEntry."Shortcut Dimension 8 Code" := DimSetEntry."Dimension Value Code";
            end;
        until DimSetEntry.Next() = 0;
    end;

    // ── Private: outstanding amount maintenance ───────────────────────────────

    local procedure UpdateSalesInvLineOutstandingAmt(var SalesInvLine: Record "Sales Invoice Line")
    begin
        // Outstanding Amt = original line amount minus the sum of all settled amounts.
        // "Settled Amt (LCY)" is a FlowField — CalcFields forces recalculation including
        // the newly inserted Settlement Entry from this same transaction.
        SalesInvLine.CalcFields("Settled Amt (LCY)");
        SalesInvLine."Outstanding Amt (LCY)" := SalesInvLine.Amount - SalesInvLine."Settled Amt (LCY)";
        SalesInvLine.Modify();
    end;
}
