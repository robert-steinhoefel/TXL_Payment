namespace P3.TXL.Payment.Settlement;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.Dimension;
using Microsoft.Finance.ReceivablesPayables;
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
///   Epic 2 — Full Settlement (payment = invoice): auto-distribute to lines
///   Epic 3 — Partial Payments: manual allocation page + unallocated entry for overpayment
///   Epic 5 — Reversals + Credit Memos: add CreateReversalEntries
///   Epic 9 — Purchase Area: add CreatePurchSettlementEntries (mirrors sales logic)
///
/// Called from:
///   EventSubscriber.OnAfterCodeGenJnlPostBatch               (sales — gen journal path)
///   EventSubscriber.OnBeforeRunUpdateAnalysisViewCustApply   (sales — CLE apply path)
///   EventSubscriber.OnAfterInsertDetailedVendorLedgerEntry   (purchase, Epic 9)
///
/// Duplicate-guard design:
///   BC creates Application DCLEs only for the side that fully closes (Remaining → 0).
///   Both the invoice DCLE and the payment DCLE may fire for the same application
///   depending on which side closes first or whether the user applies from the invoice
///   or payment perspective. To prevent double-processing, every Settlement Entry stores
///   "Source Transaction No." and SettlementEntriesExistForTransaction() is checked
///   at the top of every entry-creation path.
/// </summary>
codeunit 51106 "Settlement Entry Mgt."
{
    Permissions =
        tabledata "Settlement Entry" = ri,
        tabledata "Sales Invoice Line" = rm,
        tabledata "Cust. Ledger Entry" = r,
        tabledata "Detailed Cust. Ledg. Entry" = r,
        tabledata "Bank Account Ledger Entry" = r,
        tabledata "General Ledger Setup" = r,
        tabledata "Dimension Set Entry" = r,
        tabledata Customer = r,
        tabledata "G/L Account" = r;

    var
        AllocationCancelledErr: Label 'Payment allocation cancelled. The payment application has been rolled back and no entries have been posted.';

    // ── Public entry points ──────────────────────────────────────────────────

    /// <summary>
    /// Called from ScanBatchForPartialPayments (via the OnBeforeCode event on
    /// Gen. Jnl.-Post Batch, which fires before any write transaction).
    /// Opens the allocation page modally — RunModal is allowed in that pre-transaction context.
    /// Stores the user's distribution in Pmt. Alloc. Context keyed by invoice CLE entry no.
    /// HandlePartialPayment consumes the stored lines once OnAfterInsertEvent fires.
    /// Idempotent: exits immediately if the allocation was already collected for this invoice.
    /// </summary>
    procedure PreparePartialPaymentAllocation(InvoiceCLE: Record "Cust. Ledger Entry"; ApplicationAmtLCY: Decimal; PostingDate: Date)
    var
        AllocContext: Codeunit "Pmt. Alloc. Context";
        AllocPage: Page "Payment Allocation";
        TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary;
    begin
        if AllocContext.IsHandled(InvoiceCLE."Entry No.") then
            exit;
        AllocPage.SetContext(InvoiceCLE, ApplicationAmtLCY, PostingDate, '', '');
        AllocPage.RunModal();
        if not AllocPage.GetApplied() then
            Error(AllocationCancelledErr);
        AllocPage.GetAllocationLines(TempBuffer);
        AllocContext.StoreAllocation(InvoiceCLE."Entry No.", TempBuffer);
    end;

    /// <summary>
    /// Called from EventSubscriber when an invoice-side Application DCLE fires.
    /// BC sets "Remaining Amount", "Closed by Entry No.", and "Pmt. Disc. Given (LCY)"
    /// on the CLE before inserting Application DCLEs — all fields are reliable at this point.
    /// </summary>
    procedure CreateSalesSettlementEntries(InvoiceCLE: Record "Cust. Ledger Entry"; InvoiceDCLE: Record "Detailed Cust. Ledg. Entry"; PostingDate: Date)
    begin
        if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::Invoice then
            exit;
        ProcessInvoiceCLEForSettlement(InvoiceCLE, InvoiceDCLE, PostingDate);
    end;

    /// <summary>
    /// Called from EventSubscriber when a payment-side Application DCLE fires.
    /// BC only creates an Application DCLE for the side that fully closes (Remaining → 0).
    /// For partial payments via gen journal the payment closes fully but the invoice
    /// stays partially open — no invoice DCLE is created in that flow.
    /// The invoice CLE is found directly via PaymentDCLE."Applied Cust. Ledger Entry No."
    /// — direction-independent and more reliable than filtering by Transaction No.
    /// The guard prevents double-processing when the invoice DCLE also fires
    /// (full payment / overpayment handled by CreateSalesSettlementEntries).
    /// Only fires HandlePartialPayment when the invoice has a non-zero Remaining Amount,
    /// confirming BC has not fully closed the invoice in this application.
    /// </summary>
    procedure HandlePaymentApplicationDCLE(PaymentDCLE: Record "Detailed Cust. Ledg. Entry"; PostingDate: Date)
    var
        InvoiceCLE: Record "Cust. Ledger Entry";
    begin
        // Guard: if entries were already created by the invoice-DCLE path, skip.
        // This fires when both sides close (full payment / apply-from-invoice direction).
        if SettlementEntriesExistForTransaction(PaymentDCLE."Transaction No.") then
            exit;

        // The payment DCLE knows exactly which CLE was applied against via "Applied Cust. Ledger
        // Entry No." — use a direct Get instead of a Transaction No. + Remaining Amount filter.
        // This is direction-independent and does not depend on CLE update order.
        if PaymentDCLE."Applied Cust. Ledger Entry No." = 0 then
            exit;
        if not InvoiceCLE.Get(PaymentDCLE."Applied Cust. Ledger Entry No.") then
            exit;
        if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::Invoice then
            exit;

        // Only handle partial payments — fully-settled invoices are handled by the invoice-DCLE
        // path (ProcessInvoiceCLEForSettlement). "Open" is a stored Boolean; no CalcFields needed.
        if not InvoiceCLE.Open then
            exit;

        // PaymentDCLE."Amount (LCY)" is positive when the payment closes (remaining → 0).
        // Pass the payment CLE entry no. so HandlePartialPayment can find the bank entry via
        // the original payment-posting Transaction No. (not the application transaction).
        HandlePartialPayment(
            InvoiceCLE, PaymentDCLE."Amount (LCY)", PostingDate,
            PaymentDCLE."Transaction No.", PaymentDCLE."Cust. Ledger Entry No.");
    end;

    /// <summary>
    /// Post-commit entry point called from OnAfterCode (Gen. Jnl.-Post Batch) and
    /// OnBeforeRunUpdateAnalysisView (CustEntry-Apply Posted Entries) — both fire after
    /// the posting transaction has committed, in a fresh transaction context.
    ///
    /// Finds all Application DCLEs with Entry No. > BaselineDCLEEntryNo (the snapshot
    /// taken before the posting started) and routes each one through the existing
    /// settlement-entry creation logic. Invoice-side DCLEs are processed first (primary
    /// handler); payment-side DCLEs are processed second as a safety net, relying on the
    /// SettlementEntriesExistForTransaction guard to skip already-handled applications.
    ///
    /// Refund DCLEs are excluded — handled in Epic 9.
    /// </summary>
    procedure ProcessNewApplicationDCLEs(BaselineDCLEEntryNo: Integer)
    var
        DCLE: Record "Detailed Cust. Ledg. Entry";
        InvoiceCLE: Record "Cust. Ledger Entry";
        HandledInvoiceCLEs: List of [Integer];
    begin
        // ── Invoice-side DCLEs (primary handler) ───────────────────────────
        DCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
        DCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        DCLE.SetRange("Initial Document Type", "Gen. Journal Document Type"::Invoice);
        if DCLE.FindSet() then
            repeat
                if InvoiceCLE.Get(DCLE."Cust. Ledger Entry No.") then
                    if InvoiceCLE."Document Type" = "Gen. Journal Document Type"::Invoice then begin
                        // For partial payments (invoice stays open), BC may not populate
                        // "Applied Cust. Ledger Entry No." on the invoice DCLE (apply-from-invoice
                        // direction). Resolve it from the counterpart payment DCLE so that
                        // HandlePartialPayment can look up the correct bank ledger entry.
                        if InvoiceCLE.Open then
                            ResolveAppliedCLEEntryNo(DCLE, BaselineDCLEEntryNo);
                        CreateSalesSettlementEntries(InvoiceCLE, DCLE, DCLE."Posting Date");
                        HandledInvoiceCLEs.Add(InvoiceCLE."Entry No.");
                    end;
            until DCLE.Next() = 0;

        // ── Payment-side DCLEs (safety net) ─────────────────────────────────
        // SettlementEntriesExistForTransaction guards against double-processing when
        // Transaction No. is non-zero (gen journal path). For CLE apply path,
        // Transaction No. may be 0 (guard is bypassed by design), so HandledInvoiceCLEs
        // provides an in-process dedup: skip any invoice already handled by the invoice loop.
        DCLE.Reset();
        DCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
        DCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        DCLE.SetRange("Initial Document Type", "Gen. Journal Document Type"::Payment);
        if DCLE.FindSet() then
            repeat
                if not HandledInvoiceCLEs.Contains(DCLE."Applied Cust. Ledger Entry No.") then
                    HandlePaymentApplicationDCLE(DCLE, DCLE."Posting Date");
            until DCLE.Next() = 0;
    end;

    // ── Private: per-invoice processing ─────────────────────────────────────

    local procedure ProcessInvoiceCLEForSettlement(InvoiceCLE: Record "Cust. Ledger Entry"; InvoiceDCLE: Record "Detailed Cust. Ledg. Entry"; PostingDate: Date)
    var
        PaymentCLE: Record "Cust. Ledger Entry";
        SalesInvLine: Record "Sales Invoice Line";
        BankLedgEntry: Record "Bank Account Ledger Entry";
        AssignmentID: Code[50];
        TransactionNo: Integer;
        PaymentAmtLCY: Decimal;
        CashDiscountAmtLCY: Decimal;
        TotalAmtExclVAT: Decimal;
        TotalAmtInclVAT: Decimal;
        TotalLines: Integer;
    begin
        if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::Invoice then
            exit;

        TransactionNo := InvoiceDCLE."Transaction No.";

        // Guard: skip if a payment-DCLE handler already created entries for this transaction
        // (e.g., payment DCLE fired first for a partial payment from gen journal).
        if SettlementEntriesExistForTransaction(TransactionNo) then
            exit;

        // ── Partial payment: invoice not fully settled → manual allocation ──
        // "Open" is a stored Boolean (field 52) set by BC to false only when the invoice is
        // fully closed. Checking it avoids CalcFields on "Remaining Amount" (which is a FlowField
        // and returns 0 after a plain Get).
        // InvoiceDCLE."Amount (LCY)" is negative (reduces AR); negate for positive cash amount.
        // "Applied Cust. Ledger Entry No." is the payment CLE entry no. — passed so that
        // HandlePartialPayment can resolve the bank entry via the original payment transaction.
        if InvoiceCLE.Open then begin
            HandlePartialPayment(
                InvoiceCLE, -InvoiceDCLE."Amount (LCY)", PostingDate,
                TransactionNo, InvoiceDCLE."Applied Cust. Ledger Entry No.");
            exit;
        end;

        // ── Guard: settled by a payment, not a credit memo (→ Epic 5) ───────
        // TryGetPaymentCLE also populates PaymentCLE so it is ready for bank/overpayment lookups.
        if not TryGetPaymentCLE(InvoiceDCLE, InvoiceCLE, PaymentCLE) then
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
        // Cash discount: BC sets "Pmt. Disc. Given (LCY)" before inserting DCLEs — always reliable.
        CashDiscountAmtLCY := GetCashDiscountAmt(InvoiceCLE);

        // Payment amount for THIS invoice = the actual amount applied to this invoice
        // (negated from the invoice DCLE) minus any cash discount.
        // Using TotalAmtInclVAT would be wrong when prior partial payments exist,
        // because the invoice total exceeds the amount settled in this application.
        // Using -InvoiceDCLE."Amount (LCY)" gives the exact applied amount in all scenarios:
        // full payment, overpayment, and final partial closing a previously-partial invoice.
        PaymentAmtLCY := -InvoiceDCLE."Amount (LCY)" - CashDiscountAmtLCY;

        // ── Context for all Settlement Entries in this application ───────────
        BankLedgEntry := GetBankLedgEntryByPaymentCLE(PaymentCLE);
        AssignmentID := GenerateAssignmentID(InvoiceCLE."Customer No.", PostingDate);

        // ── Create one Settlement Entry per non-zero invoice line ────────────
        SalesInvLine.FindSet(); // Reset cursor — filters are preserved from above
        CreateSalesLineEntries(
            SalesInvLine, TotalLines, InvoiceCLE, PostingDate, BankLedgEntry,
            TotalAmtExclVAT, TotalAmtInclVAT,
            PaymentAmtLCY, CashDiscountAmtLCY, AssignmentID, TransactionNo);

        // ── Overpayment: payment > invoice → insert unallocated entry ────────
        // Re-read the payment CLE to get the post-application "Remaining Amount".
        // PaymentCLE."Remaining Amount" < 0 means the payment has unused AR credit remaining
        // (e.g., customer paid 1,500 on a 1,190 invoice → Remaining = -310).
        // Negate the negative remaining to store a positive unallocated amount.
        // The unallocated entry carries the same Assignment ID as the line entries so
        // the full payment event stays grouped; it is deleted/modified in Epic 3.3.
        PaymentCLE.Get(PaymentCLE."Entry No."); // fresh read for post-application Remaining Amount
        if PaymentCLE."Remaining Amount" < 0 then
            InsertUnallocatedEntry(
                InvoiceCLE."Customer No.", PaymentCLE, PostingDate, BankLedgEntry, AssignmentID, TransactionNo);
    end;

    // ── Private: partial payment handling ────────────────────────────────────

    /// <summary>
    /// Creates partial Settlement Entries using allocation lines pre-collected by
    /// ScanBatchForPartialPayments (Gen. Journal path) or ScanCLEApplicationForPartialPayments
    /// (manual CLE apply path). Both pre-posting hooks run before any write transaction, so
    /// RunModal is never called here. If no pre-collected allocation is found, an error is raised
    /// to surface unexpected code paths rather than silently auto-distributing.
    /// ApplicationAmtLCY is the positive cash amount applied to this invoice.
    /// TransactionNo is stored on every created Settlement Entry for the duplicate guard.
    /// </summary>
    /// <summary>
    /// PaymentCLEEntryNo: the Cust. Ledger Entry No. of the payment CLE involved in this
    /// application. Used to look up the bank entry via the payment's original Transaction No.
    /// For the gen journal path, the payment and application share the same transaction, so
    /// GetBankLedgEntryByTransactionNo would also work — but passing PaymentCLEEntryNo is
    /// consistent and correct in all paths including the CLE apply path (where the application
    /// transaction differs from the original payment-posting transaction).
    /// </summary>
    local procedure HandlePartialPayment(InvoiceCLE: Record "Cust. Ledger Entry"; ApplicationAmtLCY: Decimal; PostingDate: Date; TransactionNo: Integer; PaymentCLEEntryNo: Integer)
    var
        AllocContext: Codeunit "Pmt. Alloc. Context";
        TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary;
        PaymentCLE: Record "Cust. Ledger Entry";
        BankLedgEntry: Record "Bank Account Ledger Entry";
        AssignmentID: Code[50];
    begin
        // The allocation must have been pre-collected by ScanBatchForPartialPayments (Gen. Journal
        // path) or ScanCLEApplicationForPartialPayments (CLE apply path) before any write
        // transaction began. If nothing was stored, the pre-posting hook was not reached — error
        // rather than silently auto-distributing, to surface unexpected code paths.
        if not AllocContext.TryGetAllocation(InvoiceCLE."Entry No.", TempBuffer) then
            Error(AllocationCancelledErr);
        AllocContext.ClearAllocation(InvoiceCLE."Entry No.");

        if TempBuffer.IsEmpty() then
            exit; // No lines found (invoice has no posted sales lines) — skip silently.

        // Use the payment CLE's original Transaction No. to find the bank entry.
        // The application transaction (TransactionNo) is a separate BC transaction for the
        // CLE apply path and will not match the bank entry's Transaction No. in that case.
        //
        // For the apply-from-invoice path, BC may leave "Applied Cust. Ledger Entry No." on
        // the invoice DCLE as 0 or as the invoice's own entry no (self-reference). In either
        // case PaymentCLEEntryNo is not usable for a bank lookup. Fall back to the payment CLE
        // stored at pre-scan time by ScanForCLEPartialPayments (always valid if set).
        if (PaymentCLEEntryNo = 0) or (PaymentCLEEntryNo = InvoiceCLE."Entry No.") then
            PaymentCLEEntryNo := AllocContext.GetPaymentCLE(InvoiceCLE."Entry No.");
        AllocContext.ClearPaymentCLE(InvoiceCLE."Entry No.");

        if PaymentCLEEntryNo <> 0 then begin
            if PaymentCLE.Get(PaymentCLEEntryNo) then
                BankLedgEntry := GetBankLedgEntryByPaymentCLE(PaymentCLE);
        end else
            BankLedgEntry := GetBankLedgEntryByTransactionNo(TransactionNo);

        AssignmentID := GenerateAssignmentID(InvoiceCLE."Customer No.", PostingDate);
        CreatePartialLineEntries(TempBuffer, InvoiceCLE, PostingDate, BankLedgEntry, AssignmentID, TransactionNo);
    end;

    /// <summary>
    /// Scans all Gen. Journal lines in the same batch as GenJnlLine for lines that will
    /// result in a partial application (Applies-to Doc. No. set, payment amount less than
    /// invoice remaining amount). For each one found, opens the allocation page via
    /// PreparePartialPaymentAllocation and stores the result in Pmt. Alloc. Context.
    /// Called from OnBeforeCode on Gen. Jnl.-Post Batch — before any write transaction,
    /// so RunModal is allowed.
    /// </summary>
    procedure ScanBatchForPartialPayments(var GenJnlLine: Record "Gen. Journal Line")
    var
        BatchLine: Record "Gen. Journal Line";
        InvoiceCLE: Record "Cust. Ledger Entry";
    begin
        BatchLine.SetRange("Journal Template Name", GenJnlLine."Journal Template Name");
        BatchLine.SetRange("Journal Batch Name", GenJnlLine."Journal Batch Name");
        BatchLine.SetRange("Account Type", BatchLine."Account Type"::Customer);
        BatchLine.SetRange("Applies-to Doc. Type", "Gen. Journal Document Type"::Invoice);
        BatchLine.SetFilter("Applies-to Doc. No.", '<>%1', '');
        if not BatchLine.FindSet() then
            exit;

        repeat
            if FindInvoiceCLEForJnlLine(BatchLine, InvoiceCLE) then
                if IsPartialApplication(BatchLine, InvoiceCLE) then
                    PreparePartialPaymentAllocation(
                        InvoiceCLE, Abs(BatchLine."Amount (LCY)"), BatchLine."Posting Date");
        until BatchLine.Next() = 0;
    end;

    /// <summary>
    /// CLE apply path entry point. Called from OnBeforeApply on CustEntry-Apply Posted Entries
    /// (codeunit 226), which fires before any write transaction (before LockTable on DCLE) —
    /// RunModal is allowed here.
    /// CustLedgEntry is the applying entry: payment CLE when applying FROM a payment,
    /// invoice CLE when applying FROM an invoice.
    /// </summary>
    procedure ScanCLEApplicationForPartialPayments(CustLedgEntry: Record "Cust. Ledger Entry"; ApplicationDate: Date)
    begin
        ScanForCLEPartialPayments(CustLedgEntry."Customer No.", CustLedgEntry, ApplicationDate);
    end;

    /// <summary>
    /// Gen. Journal apply path entry point. Called from OnBeforeCode on Gen. Jnl.-Post Batch,
    /// which fires before any write transaction — RunModal is allowed.
    /// </summary>
    procedure ScanManualApplicationForPartialPayments(GenJnlLine: Record "Gen. Journal Line"; CustLedgEntry: Record "Cust. Ledger Entry")
    var
        CustomerNo: Code[20];
    begin
        CustomerNo := GenJnlLine."Account No.";
        if CustomerNo = '' then
            CustomerNo := CustLedgEntry."Customer No.";
        ScanForCLEPartialPayments(CustomerNo, CustLedgEntry, GenJnlLine."Posting Date");
    end;

    /// <summary>
    /// Core partial-payment scan shared by both apply-path entry points.
    /// Apply-from-invoice: CustLedgEntry IS the invoice CLE — sum payment CLEs with
    ///   "Amount to Apply" set to get the total amount being applied.
    /// Apply-from-payment: CustLedgEntry IS the payment (or empty) — scan invoice CLEs
    ///   with "Amount to Apply" set for this customer.
    /// </summary>
    local procedure ScanForCLEPartialPayments(CustomerNo: Code[20]; CustLedgEntry: Record "Cust. Ledger Entry"; PostingDate: Date)
    var
        AllocContext: Codeunit "Pmt. Alloc. Context";
        InvoiceCLE: Record "Cust. Ledger Entry";
        ApplicationAmt: Decimal;
    begin
        if CustomerNo = '' then
            exit;

        // Apply-from-invoice direction: invoice CLE is passed directly as driving entry.
        // Entry No. <> 0 guards against an empty/uninitialized record.
        if (CustLedgEntry."Entry No." <> 0) and
           (CustLedgEntry."Document Type" = "Gen. Journal Document Type"::Invoice) and
           CustLedgEntry.Open
        then begin
            CustLedgEntry.CalcFields("Remaining Amount");
            ApplicationAmt := CalcTotalPaymentAmtToApply(CustomerNo);
            if (CustLedgEntry."Remaining Amount" > 0) and
               (ApplicationAmt > 0) and
               (ApplicationAmt < CustLedgEntry."Remaining Amount" - CustLedgEntry."Remaining Pmt. Disc. Possible" - 0.005)
            then begin
                PreparePartialPaymentAllocation(CustLedgEntry, ApplicationAmt, PostingDate);
                // For apply-from-invoice, BC does not reliably populate "Applied Cust. Ledger Entry No."
                // on the invoice DCLE with the payment CLE entry no. Store the applying payment CLE
                // now (while "Amount to Apply" is still set) so HandlePartialPayment can resolve it.
                AllocContext.StorePaymentCLE(CustLedgEntry."Entry No.", FindApplyingPaymentCLEEntryNo(CustomerNo));
            end;
            exit;
        end;

        // Apply-from-payment direction: find open invoice CLEs with Amount to Apply set.
        InvoiceCLE.SetRange("Customer No.", CustomerNo);
        InvoiceCLE.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        InvoiceCLE.SetRange(Open, true);
        InvoiceCLE.SetFilter("Amount to Apply", '<>0');
        if not InvoiceCLE.FindSet() then
            exit;
        repeat
            InvoiceCLE.CalcFields("Remaining Amount");
            if InvoiceCLE."Remaining Amount" > 0 then begin
                ApplicationAmt := Abs(InvoiceCLE."Amount to Apply");
                // BC defaults "Amount to Apply" on the invoice to its full remaining amount,
                // regardless of how much the payment CLE can actually cover. When they are equal,
                // the partial check below fails even though the payment may only cover a fraction.
                // Fall back to the payment CLE's Remaining Amount as the effective applied amount.
                // NOTE: "Amount to Apply" on the payment CLE is 0 when applying FROM the payment
                // page — the page sets Amount to Apply only on the invoice CLEs, not the payment.
                // "Remaining Amount" on the payment CLE reflects the actual available credit.
                if ApplicationAmt >= InvoiceCLE."Remaining Amount" - InvoiceCLE."Remaining Pmt. Disc. Possible" - 0.005 then begin
                    CustLedgEntry.CalcFields("Remaining Amount");
                    ApplicationAmt := Abs(CustLedgEntry."Remaining Amount");
                end;
                if (ApplicationAmt > 0) and
                   (ApplicationAmt < InvoiceCLE."Remaining Amount" - InvoiceCLE."Remaining Pmt. Disc. Possible" - 0.005)
                then
                    PreparePartialPaymentAllocation(InvoiceCLE, ApplicationAmt, PostingDate);
            end;
        until InvoiceCLE.Next() = 0;
    end;

    /// <summary>
    /// Sums the "Amount to Apply" of all payment/refund CLEs currently marked for application
    /// for the given customer. Used when applying FROM an invoice CLE, where the invoice's own
    /// "Amount to Apply" is 0 and the payment CLEs carry the applied amounts instead.
    /// </summary>
    local procedure CalcTotalPaymentAmtToApply(CustomerNo: Code[20]): Decimal
    var
        PaymentCLE: Record "Cust. Ledger Entry";
    begin
        PaymentCLE.SetRange("Customer No.", CustomerNo);
        PaymentCLE.SetFilter(
            "Document Type", '%1|%2',
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund);
        PaymentCLE.SetFilter("Amount to Apply", '<>0');
        PaymentCLE.CalcSums("Amount to Apply");
        exit(Abs(PaymentCLE."Amount to Apply"));
    end;

    local procedure FindInvoiceCLEForJnlLine(GenJnlLine: Record "Gen. Journal Line"; var InvoiceCLE: Record "Cust. Ledger Entry"): Boolean
    begin
        InvoiceCLE.SetRange("Customer No.", GenJnlLine."Account No.");
        InvoiceCLE.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        InvoiceCLE.SetRange("Document No.", GenJnlLine."Applies-to Doc. No.");
        InvoiceCLE.SetRange(Open, true);
        exit(InvoiceCLE.FindFirst());
    end;

    local procedure IsPartialApplication(GenJnlLine: Record "Gen. Journal Line"; var InvoiceCLE: Record "Cust. Ledger Entry"): Boolean
    begin
        InvoiceCLE.CalcFields("Remaining Amount");
        if InvoiceCLE."Remaining Amount" <= 0 then
            exit(false);
        // Use a small tolerance to avoid floating-point false positives on exact payments.
        exit(Abs(GenJnlLine."Amount (LCY)") < InvoiceCLE."Remaining Amount" - 0.005);
    end;

    /// <summary>
    /// Proportionally distributes ApplicationAmtLCY across the invoice lines into TempBuffer.
    /// Used by the page's "Distribute Proportionally" action and for pre-populating suggestions.
    /// The last line absorbs any rounding difference.
    /// NOTE: No longer called as an automatic fallback — HandlePartialPayment now errors if no
    /// pre-collected allocation exists. Kept for potential future reuse (e.g., page action).
    /// </summary>
    local procedure AutoDistributeProportionally(InvoiceCLE: Record "Cust. Ledger Entry"; ApplicationAmtLCY: Decimal; var TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary)
    var
        SalesInvLine: Record "Sales Invoice Line";
        TotalOrigAmtInclVAT: Decimal;
        Remaining: Decimal;
        LineCount: Integer;
        CurrentLine: Integer;
    begin
        SalesInvLine.SetRange("Document No.", InvoiceCLE."Document No.");
        SalesInvLine.SetFilter(Amount, '<>0');
        if not SalesInvLine.FindSet() then
            exit;
        repeat
            TotalOrigAmtInclVAT += SalesInvLine."Amount Including VAT";
            LineCount += 1;
        until SalesInvLine.Next() = 0;
        if TotalOrigAmtInclVAT = 0 then
            exit;

        Remaining := ApplicationAmtLCY;
        SalesInvLine.FindSet();
        repeat
            CurrentLine += 1;
            TempBuffer.Init();
            TempBuffer."Line No." := SalesInvLine."Line No.";
            TempBuffer.Description := CopyStr(SalesInvLine.Description, 1, MaxStrLen(TempBuffer.Description));
            TempBuffer."G/L Account No." := CopyStr(SalesInvLine."No.", 1, MaxStrLen(TempBuffer."G/L Account No."));
            TempBuffer."Original Amt (LCY)" := SalesInvLine.Amount;
            TempBuffer."Orig. Amt Incl. VAT (LCY)" := SalesInvLine."Amount Including VAT";
            TempBuffer."Global Dimension 1 Code" := SalesInvLine."Shortcut Dimension 1 Code";
            TempBuffer."Global Dimension 2 Code" := SalesInvLine."Shortcut Dimension 2 Code";
            TempBuffer."Dimension Set ID" := SalesInvLine."Dimension Set ID";
            if CurrentLine = LineCount then
                TempBuffer."Alloc. Amt Incl. VAT (LCY)" := Remaining
            else begin
                TempBuffer."Alloc. Amt Incl. VAT (LCY)" :=
                    Round(ApplicationAmtLCY * SalesInvLine."Amount Including VAT" / TotalOrigAmtInclVAT);
                Remaining -= TempBuffer."Alloc. Amt Incl. VAT (LCY)";
            end;
            TempBuffer.Insert();
        until SalesInvLine.Next() = 0;
    end;

    local procedure CreatePartialLineEntries(
        var TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary;
        InvoiceCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        AssignmentID: Code[50];
        TransactionNo: Integer)
    var
        Customer: Record Customer;
    begin
        Customer.Get(InvoiceCLE."Customer No.");
        if TempBuffer.FindSet() then
            repeat
                if TempBuffer."Alloc. Amt Incl. VAT (LCY)" <> 0 then
                    InsertPartialSalesSettlementEntry(
                        TempBuffer, InvoiceCLE, PostingDate, BankLedgEntry, Customer, AssignmentID, TransactionNo);
            until TempBuffer.Next() = 0;
    end;

    local procedure InsertPartialSalesSettlementEntry(
        TempBuffer: Record "Pmt. Alloc. Line Buffer";
        InvoiceCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        Customer: Record Customer;
        AssignmentID: Code[50];
        TransactionNo: Integer)
    var
        SettlementEntry: Record "Settlement Entry";
        GLAccount: Record "G/L Account";
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
    begin
        SettlementEntry.Init();

        SettlementEntry."Transaction Type" := "Settlement Transaction Type"::Sales;
        SettlementEntry."Document Type" := "Gen. Journal Document Type"::Invoice;
        SettlementEntry."Document No." := InvoiceCLE."Document No.";
        SettlementEntry."Document Line No." := TempBuffer."Line No.";

        SettlementEntry."Assignment ID" := AssignmentID;
        SettlementEntry."Settlement Date" := PostingDate;

        // User entered incl. VAT; back-calculate excl. VAT proportionally from line ratio.
        LineAmtInclVAT := TempBuffer."Alloc. Amt Incl. VAT (LCY)";
        if TempBuffer."Orig. Amt Incl. VAT (LCY)" <> 0 then
            LineAmt := Round(LineAmtInclVAT * TempBuffer."Original Amt (LCY)" / TempBuffer."Orig. Amt Incl. VAT (LCY)")
        else
            LineAmt := LineAmtInclVAT;

        SettlementEntry."Settlement Amt (LCY)" := LineAmt;
        SettlementEntry."Settlement Amt Incl. VAT (LCY)" := LineAmtInclVAT;
        SettlementEntry."Cash Discount Amt (LCY)" := 0;

        SettlementEntry."Original Line Amt (LCY)" := TempBuffer."Original Amt (LCY)";
        SettlementEntry."Orig. Line Amt Incl. VAT (LCY)" := TempBuffer."Orig. Amt Incl. VAT (LCY)";

        SettlementEntry."Bank Statement Document No." := BankLedgEntry."Document No.";

        SettlementEntry."CV No." := InvoiceCLE."Customer No.";
        SettlementEntry."CV Name" := Customer.Name;

        SettlementEntry."Global Dimension 1 Code" := TempBuffer."Global Dimension 1 Code";
        SettlementEntry."Global Dimension 2 Code" := TempBuffer."Global Dimension 2 Code";
        SettlementEntry."Dimension Set ID" := TempBuffer."Dimension Set ID";
        PopulateShortcutDimensions(SettlementEntry, TempBuffer."Dimension Set ID");

        SettlementEntry."G/L Account No." := TempBuffer."G/L Account No.";
        if GLAccount.Get(TempBuffer."G/L Account No.") then
            SettlementEntry."G/L Account Name" := GLAccount.Name;

        SettlementEntry.Description :=
            CopyStr(TempBuffer.Description, 1, MaxStrLen(SettlementEntry.Description));

        SettlementEntry."Source Transaction No." := TransactionNo;
        SettlementEntry."Created By" := CopyStr(UserId(), 1, MaxStrLen(SettlementEntry."Created By"));
        SettlementEntry."Created DateTime" := CurrentDateTime();

        SettlementEntry.Insert(true);

        UpdateSalesInvLineOutstandingAmtByLineNo(InvoiceCLE."Document No.", TempBuffer."Line No.");
    end;

    // ── Private: overpayment unallocated entry ───────────────────────────────

    local procedure InsertUnallocatedEntry(
        CustomerNo: Code[20];
        var PaymentCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        AssignmentID: Code[50];
        TransactionNo: Integer)
    var
        SettlementEntry: Record "Settlement Entry";
        Customer: Record Customer;
    begin
        Customer.Get(CustomerNo);

        SettlementEntry.Init();
        SettlementEntry."Settlement Entry Type" := "Settlement Entry Type"::Unallocated;
        SettlementEntry."Transaction Type" := "Settlement Transaction Type"::Sales;
        SettlementEntry."Document Type" := "Gen. Journal Document Type"::Payment;
        // Document No. intentionally blank — visual signal in the list that this amount is unallocated.
        SettlementEntry."Bank Statement Document No." := BankLedgEntry."Document No.";

        // Share the same Assignment ID as the invoice line entries so the full
        // payment event stays grouped in reporting.
        SettlementEntry."Assignment ID" := AssignmentID;
        SettlementEntry."Settlement Date" := PostingDate;

        // Remaining Amount on Payment CLE is negative (unused AR credit) → negate for positive amount.
        SettlementEntry."Settlement Amt (LCY)" := -PaymentCLE."Remaining Amount";
        SettlementEntry."Settlement Amt Incl. VAT (LCY)" := -PaymentCLE."Remaining Amount";

        SettlementEntry."CV No." := CustomerNo;
        SettlementEntry."CV Name" := Customer.Name;

        SettlementEntry."Source Transaction No." := TransactionNo;
        SettlementEntry."Created By" := CopyStr(UserId(), 1, MaxStrLen(SettlementEntry."Created By"));
        SettlementEntry."Created DateTime" := CurrentDateTime();

        SettlementEntry.Insert(true);
    end;

    /// <summary>
    /// Returns the entry no. of the first payment/refund CLE with "Amount to Apply" set for
    /// the given customer. Called at pre-scan time (before posting) when Amount to Apply is
    /// still populated. Returns 0 if none is found.
    /// </summary>
    local procedure FindApplyingPaymentCLEEntryNo(CustomerNo: Code[20]): Integer
    var
        PaymentCLE: Record "Cust. Ledger Entry";
    begin
        PaymentCLE.SetRange("Customer No.", CustomerNo);
        PaymentCLE.SetFilter(
            "Document Type", '%1|%2',
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund);
        PaymentCLE.SetFilter("Amount to Apply", '<>0');
        if PaymentCLE.FindFirst() then
            exit(PaymentCLE."Entry No.");
        exit(0);
    end;

    // ── Private: DCLE field resolution ──────────────────────────────────────

    /// <summary>
    /// Patches InvoiceDCLE."Applied Cust. Ledger Entry No." when it is 0.
    /// This occurs on the apply-from-invoice path for partial payments: BC does not
    /// populate the field on the invoice-side DCLE when the invoice remains open.
    /// The counterpart payment DCLE (Entry No. > BaselineDCLEEntryNo, same application)
    /// always carries the payment CLE entry no. in "Cust. Ledger Entry No.".
    /// Only modifies the local record — no database write.
    /// </summary>
    local procedure ResolveAppliedCLEEntryNo(var InvoiceDCLE: Record "Detailed Cust. Ledg. Entry"; BaselineDCLEEntryNo: Integer)
    var
        PaymentDCLE: Record "Detailed Cust. Ledg. Entry";
    begin
        // Exit if "Applied" already points to a different CLE (i.e., the payment CLE).
        // Treat self-references (Applied = own CLE entry no) as equivalent to 0 — BC sets
        // this on invoice DCLEs in the apply-from-invoice direction when the invoice stays open.
        if (InvoiceDCLE."Applied Cust. Ledger Entry No." <> 0) and
           (InvoiceDCLE."Applied Cust. Ledger Entry No." <> InvoiceDCLE."Cust. Ledger Entry No.") then
            exit;
        PaymentDCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
        PaymentDCLE.SetRange("Applied Cust. Ledger Entry No.", InvoiceDCLE."Cust. Ledger Entry No.");
        PaymentDCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        PaymentDCLE.SetFilter(
            "Initial Document Type", '%1|%2',
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund);
        PaymentDCLE.SetRange(Unapplied, false);
        if PaymentDCLE.FindFirst() then
            InvoiceDCLE."Applied Cust. Ledger Entry No." := PaymentDCLE."Cust. Ledger Entry No.";
    end;

    // ── Private: duplicate guard ─────────────────────────────────────────────

    /// <summary>
    /// Returns true if any Settlement Entry was already created for the given BC transaction.
    /// Used to prevent double-processing when both the invoice-side and payment-side
    /// Application DCLEs fire for the same application event.
    /// </summary>
    local procedure SettlementEntriesExistForTransaction(TransactionNo: Integer): Boolean
    var
        ExistingEntry: Record "Settlement Entry";
    begin
        if TransactionNo = 0 then
            exit(false);
        ExistingEntry.SetRange("Source Transaction No.", TransactionNo);
        exit(not ExistingEntry.IsEmpty());
    end;

    // ── Private: application type detection ─────────────────────────────────

    /// <summary>
    /// Finds the payment CLE that settled the given invoice and populates PaymentCLE.
    /// Returns false if the application was by a credit memo (→ Epic 5).
    ///
    /// Uses the same DCLE-based lookup as CustomerLedgerEntries.Codeunit.al:
    ///   "Applied Cust. Ledger Entry No." equals the invoice entry no. on BOTH the invoice-side
    ///   and payment-side Application DCLEs, making this direction-independent.
    ///   "Transaction No." scopes to the current application only, preventing false matches
    ///   from historical partial payments on the same invoice (PARTIAL-PAYMENT-BUG-1).
    ///
    /// Fallback to "Closed by Entry No." when the payment DCLE has not yet been inserted
    /// (applies when the invoice DCLE fires before the payment DCLE in some posting paths).
    /// </summary>
    local procedure TryGetPaymentCLE(InvoiceDCLE: Record "Detailed Cust. Ledg. Entry"; var InvoiceCLE: Record "Cust. Ledger Entry"; var PaymentCLE: Record "Cust. Ledger Entry"): Boolean
    var
        PaymentDCLE: Record "Detailed Cust. Ledg. Entry";
    begin
        // Primary: the invoice-side Application DCLE stores the payment CLE entry no.
        // directly in "Applied Cust. Ledger Entry No.". This is the most direct and
        // version-independent lookup — no secondary DCLE scan needed.
        if InvoiceDCLE."Applied Cust. Ledger Entry No." <> 0 then
            if PaymentCLE.Get(InvoiceDCLE."Applied Cust. Ledger Entry No.") then
                if PaymentCLE."Document Type" in
                    ["Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund]
                then
                    exit(true);

        // Secondary: find the payment-side Application DCLE via Applied CLE No. and
        // read the payment CLE from there. Handles cases where the invoice DCLE's
        // "Applied Cust. Ledger Entry No." is unexpectedly 0 or points to a non-payment.
        PaymentDCLE.SetRange("Applied Cust. Ledger Entry No.", InvoiceDCLE."Cust. Ledger Entry No.");
        PaymentDCLE.SetRange("Transaction No.", InvoiceDCLE."Transaction No.");
        PaymentDCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        PaymentDCLE.SetRange(Unapplied, false);
        PaymentDCLE.SetFilter("Cust. Ledger Entry No.", '<>%1', InvoiceDCLE."Cust. Ledger Entry No.");
        PaymentDCLE.SetFilter(
            "Initial Document Type", '%1|%2',
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund);
        if PaymentDCLE.FindFirst() then begin
            if not PaymentCLE.Get(PaymentDCLE."Cust. Ledger Entry No.") then
                exit(false);
            exit(PaymentCLE."Document Type" in
                ["Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund]);
        end;

        // Fallback: payment DCLE not yet inserted — use "Closed by Entry No." on the invoice CLE.
        if InvoiceCLE."Closed by Entry No." = 0 then
            exit(false);
        if not PaymentCLE.Get(InvoiceCLE."Closed by Entry No.") then
            exit(false);
        exit(PaymentCLE."Document Type" in
            ["Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund]);
    end;

    // ── Private: amount helpers ──────────────────────────────────────────────

    /// <summary>
    /// Returns the cash discount amount (positive, LCY) granted in this application.
    /// "Pmt. Disc. Given (LCY)" is set by BC on the invoice CLE before Application DCLEs are
    /// inserted, so it is reliably available at OnAfterInsertDetailedCustomerLedgerEntry time.
    /// BC v27 stores this field as a positive value (absolute discount amount incl. VAT).
    /// </summary>
    local procedure GetCashDiscountAmt(var InvoiceCLE: Record "Cust. Ledger Entry"): Decimal
    begin
        exit(InvoiceCLE."Pmt. Disc. Given (LCY)");
    end;

    // ── Private: bank ledger entry lookup ────────────────────────────────────

    /// <summary>
    /// Returns the Bank Account Ledger Entry posted in the same BC transaction.
    /// Used by the partial payment path where no PaymentCLE is available but the
    /// Transaction No. from the Application DCLE identifies the posting event.
    /// Returns an empty record if no bank entry exists for this transaction.
    /// </summary>
    local procedure GetBankLedgEntryByTransactionNo(TransactionNo: Integer): Record "Bank Account Ledger Entry"
    var
        BankLedgEntry: Record "Bank Account Ledger Entry";
    begin
        if TransactionNo = 0 then begin
            Clear(BankLedgEntry);
            exit(BankLedgEntry);
        end;
        BankLedgEntry.SetRange("Transaction No.", TransactionNo);
        if BankLedgEntry.FindFirst() then
            exit(BankLedgEntry);
        Clear(BankLedgEntry);
        exit(BankLedgEntry);
    end;

    /// <summary>
    /// Returns the Bank Account Ledger Entry linked to the given payment CLE.
    /// Uses Transaction No. to find the bank entry posted in the same transaction.
    /// Returns an empty record if the payment was not posted via a bank account.
    /// </summary>
    local procedure GetBankLedgEntryByPaymentCLE(var PaymentCLE: Record "Cust. Ledger Entry"): Record "Bank Account Ledger Entry"
    var
        BankLedgEntry: Record "Bank Account Ledger Entry";
    begin
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

    // ── Private: full settlement line entry creation (Epic 2) ────────────────

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
        AssignmentID: Code[50];
        TransactionNo: Integer)
    var
        Customer: Record Customer;
        LineCount: Integer;
        RemainingAmt: Decimal;
        RemainingAmtInclVAT: Decimal;
        RemainingDiscount: Decimal;
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
        LineDiscount: Decimal;
    begin
        Customer.Get(InvoiceCLE."Customer No.");

        RemainingAmt := Round(PaymentAmtLCY * TotalAmtExclVAT / TotalAmtInclVAT);
        RemainingAmtInclVAT := PaymentAmtLCY;
        RemainingDiscount := Round(CashDiscountAmtLCY * TotalAmtExclVAT / TotalAmtInclVAT);

        repeat
            LineCount += 1;

            if LineCount = TotalLines then begin
                LineAmt := RemainingAmt;
                LineAmtInclVAT := RemainingAmtInclVAT;
                LineDiscount := RemainingDiscount;
            end else begin
                LineAmt := Round(SalesInvLine.Amount * PaymentAmtLCY / TotalAmtInclVAT);
                LineAmtInclVAT := Round(SalesInvLine."Amount Including VAT" * PaymentAmtLCY / TotalAmtInclVAT);
                LineDiscount := Round(SalesInvLine.Amount * CashDiscountAmtLCY / TotalAmtInclVAT);
                RemainingAmt -= LineAmt;
                RemainingAmtInclVAT -= LineAmtInclVAT;
                RemainingDiscount -= LineDiscount;
            end;

            InsertSalesSettlementEntry(
                SalesInvLine, InvoiceCLE, PostingDate, BankLedgEntry, Customer,
                AssignmentID, TransactionNo, LineAmt, LineAmtInclVAT, LineDiscount);

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
        TransactionNo: Integer;
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
        LineDiscount: Decimal)
    var
        SettlementEntry: Record "Settlement Entry";
        GLAccount: Record "G/L Account";
    begin
        SettlementEntry.Init();

        SettlementEntry."Transaction Type" := "Settlement Transaction Type"::Sales;
        SettlementEntry."Document Type" := "Gen. Journal Document Type"::Invoice;
        SettlementEntry."Document No." := SalesInvLine."Document No.";
        SettlementEntry."Document Line No." := SalesInvLine."Line No.";

        SettlementEntry."Assignment ID" := AssignmentID;
        SettlementEntry."Settlement Date" := PostingDate;
        SettlementEntry."Settlement Amt (LCY)" := LineAmt;
        SettlementEntry."Settlement Amt Incl. VAT (LCY)" := LineAmtInclVAT;
        SettlementEntry."Cash Discount Amt (LCY)" := LineDiscount;

        SettlementEntry."Original Line Amt (LCY)" := SalesInvLine.Amount;
        SettlementEntry."Orig. Line Amt Incl. VAT (LCY)" := SalesInvLine."Amount Including VAT";

        SettlementEntry."Bank Statement Document No." := BankLedgEntry."Document No.";

        SettlementEntry."CV No." := InvoiceCLE."Customer No.";
        SettlementEntry."CV Name" := Customer.Name;

        SettlementEntry."Global Dimension 1 Code" := SalesInvLine."Shortcut Dimension 1 Code";
        SettlementEntry."Global Dimension 2 Code" := SalesInvLine."Shortcut Dimension 2 Code";
        SettlementEntry."Dimension Set ID" := SalesInvLine."Dimension Set ID";
        PopulateShortcutDimensions(SettlementEntry, SalesInvLine."Dimension Set ID");

        if SalesInvLine.Type = SalesInvLine.Type::"G/L Account" then begin
            SettlementEntry."G/L Account No." := SalesInvLine."No.";
            if GLAccount.Get(SalesInvLine."No.") then
                SettlementEntry."G/L Account Name" := GLAccount.Name;
        end;

        SettlementEntry.Description :=
            CopyStr(SalesInvLine.Description, 1, MaxStrLen(SettlementEntry.Description));

        SettlementEntry."Source Transaction No." := TransactionNo;
        SettlementEntry."Created By" := CopyStr(UserId(), 1, MaxStrLen(SettlementEntry."Created By"));
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
        SalesInvLine.CalcFields("Settled Amt (LCY)");
        SalesInvLine."Outstanding Amt (LCY)" := SalesInvLine.Amount - SalesInvLine."Settled Amt (LCY)";
        SalesInvLine.Modify();
    end;

    local procedure UpdateSalesInvLineOutstandingAmtByLineNo(DocumentNo: Code[20]; LineNo: Integer)
    var
        SalesInvLine: Record "Sales Invoice Line";
    begin
        if not SalesInvLine.Get(DocumentNo, LineNo) then
            exit;
        UpdateSalesInvLineOutstandingAmt(SalesInvLine);
    end;
}
