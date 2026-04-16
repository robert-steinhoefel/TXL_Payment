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
        tabledata "Settlement Entry" = rim,
        tabledata "Sales Invoice Line" = rm,
        tabledata "Sales Cr.Memo Line" = rm,
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
    procedure CreateSalesSettlementEntries(InvoiceCLE: Record "Cust. Ledger Entry"; InvoiceDCLE: Record "Detailed Cust. Ledg. Entry"; PostingDate: Date; BaselineDCLEEntryNo: Integer)
    begin
        if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::Invoice then
            exit;
        ProcessInvoiceCLEForSettlement(InvoiceCLE, InvoiceDCLE, PostingDate, BaselineDCLEEntryNo);
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
        AppliedCLE: Record "Cust. Ledger Entry";
    begin
        // Guard: if entries were already created by the primary handler (invoice/CM-DCLE path), skip.
        if SettlementEntriesExistForTransaction(PaymentDCLE."Transaction No.", PaymentDCLE."Cust. Ledger Entry No.") then
            exit;

        // The payment/refund DCLE knows exactly which CLE was applied against.
        if PaymentDCLE."Applied Cust. Ledger Entry No." = 0 then
            exit;
        if not AppliedCLE.Get(PaymentDCLE."Applied Cust. Ledger Entry No.") then
            exit;

        // Only handle partial applications — fully-settled documents are handled by their own
        // DCLE path. "Open" is a stored Boolean; no CalcFields needed.
        if not AppliedCLE.Open then
            exit;

        case AppliedCLE."Document Type" of
            "Gen. Journal Document Type"::Invoice:
                // PaymentDCLE."Amount (LCY)" is positive when the payment closes (remaining → 0).
                // Pass payment CLE entry no. so HandlePartialPayment resolves the bank entry via
                // the original payment-posting Transaction No. (not the application transaction).
                HandlePartialPayment(
                    AppliedCLE, PaymentDCLE."Amount (LCY)", PostingDate,
                    PaymentDCLE."Transaction No.", PaymentDCLE."Cust. Ledger Entry No.");
            "Gen. Journal Document Type"::"Credit Memo":
                // Refund DCLE applied against a CM: mirror the invoice partial payment path.
                // Reads the pre-collected allocation from Pmt. Alloc. Context.
                HandlePartialCrMemoSettlement(
                    AppliedCLE, PostingDate,
                    PaymentDCLE."Transaction No.", PaymentDCLE."Cust. Ledger Entry No.");
        end;
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
    /// Refund DCLEs applied to credit memos are handled here (Story 5.3 partial CM support).
    /// </summary>
    procedure ProcessNewApplicationDCLEs(BaselineDCLEEntryNo: Integer)
    var
        DCLE: Record "Detailed Cust. Ledg. Entry";
        InvoiceCLE: Record "Cust. Ledger Entry";
        CrMemoCLE: Record "Cust. Ledger Entry";
        HandledInvoiceCLEs: List of [Integer];
        HandledCrMemoCLEs: List of [Integer];
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
                        CreateSalesSettlementEntries(InvoiceCLE, DCLE, DCLE."Posting Date", BaselineDCLEEntryNo);
                        HandledInvoiceCLEs.Add(InvoiceCLE."Entry No.");
                    end;
            until DCLE.Next() = 0;

        // ── Credit memo DCLEs (Epic 5 — Story 5.3, full + partial) ──────────
        // Full closure: CM CLE closes (Remaining Amount → 0) → CreateCreditMemoSettlementEntries.
        // Partial: CM CLE stays Open → HandlePartialCrMemoSettlement (pre-collected allocation).
        // HandledCrMemoCLEs provides in-process dedup for the CLE apply path (Transaction No. = 0).
        DCLE.Reset();
        DCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
        DCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        DCLE.SetRange("Initial Document Type", "Gen. Journal Document Type"::"Credit Memo");
        DCLE.SetRange(Unapplied, false);
        if DCLE.FindSet() then
            repeat
                if CrMemoCLE.Get(DCLE."Cust. Ledger Entry No.") then
                    if CrMemoCLE."Document Type" = "Gen. Journal Document Type"::"Credit Memo" then begin
                        if CrMemoCLE.Open then begin
                            if not HandledCrMemoCLEs.Contains(CrMemoCLE."Entry No.") then begin
                                HandlePartialCrMemoSettlement(
                                    CrMemoCLE, DCLE."Posting Date",
                                    DCLE."Transaction No.", DCLE."Applied Cust. Ledger Entry No.");
                                HandledCrMemoCLEs.Add(CrMemoCLE."Entry No.");
                            end;
                        end else
                            CreateCreditMemoSettlementEntries(DCLE, DCLE."Posting Date", BaselineDCLEEntryNo);
                    end;
            until DCLE.Next() = 0;

        // ── Payment/Refund-side DCLEs (safety net) ──────────────────────────
        // SettlementEntriesExistForTransaction guards against double-processing when
        // Transaction No. is non-zero (gen journal path). For CLE apply path,
        // Transaction No. may be 0 (guard is bypassed by design), so HandledInvoiceCLEs /
        // HandledCrMemoCLEs provide in-process dedup for already-handled documents.
        // Payment DCLEs → partial invoice safety net.
        // Refund DCLEs → partial CM safety net (mirrors the Payment → Invoice pattern).
        DCLE.Reset();
        DCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
        DCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        DCLE.SetFilter("Initial Document Type", '%1|%2',
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund);
        DCLE.SetRange(Unapplied, false);
        if DCLE.FindSet() then
            repeat
                if not HandledInvoiceCLEs.Contains(DCLE."Applied Cust. Ledger Entry No.") and
                   not HandledCrMemoCLEs.Contains(DCLE."Applied Cust. Ledger Entry No.")
                then
                    HandlePaymentApplicationDCLE(DCLE, DCLE."Posting Date");
            until DCLE.Next() = 0;
    end;

    // ── Private: per-invoice processing ─────────────────────────────────────

    local procedure ProcessInvoiceCLEForSettlement(InvoiceCLE: Record "Cust. Ledger Entry"; InvoiceDCLE: Record "Detailed Cust. Ledg. Entry"; PostingDate: Date; BaselineDCLEEntryNo: Integer)
    var
        PaymentDCLE: Record "Detailed Cust. Ledg. Entry";
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
        PaymentDCLECount: Integer;
        IsFallbackScan: Boolean;
    begin
        if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::Invoice then
            exit;

        TransactionNo := InvoiceDCLE."Transaction No.";

        // Guard: skip if a payment-DCLE handler already created entries for this
        // (transaction, payment CLE) pair — payment DCLE fired first for a partial payment
        // from gen journal. "Applied Cust. Ledger Entry No." on the invoice DCLE is the
        // payment CLE entry no. in this path (non-self-reference, Transaction No. > 0).
        if SettlementEntriesExistForTransaction(TransactionNo, InvoiceDCLE."Applied Cust. Ledger Entry No.") then
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

        // ── Find all payment-side Application DCLEs for this application ─────
        // Primary scan: payment-side DCLEs pointing directly to the invoice CLE.
        // Works for payments without cash discount (both gen journal and CLE apply paths)
        // and for multi-payment scenarios.
        PaymentDCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
        PaymentDCLE.SetRange("Applied Cust. Ledger Entry No.", InvoiceCLE."Entry No.");
        PaymentDCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        PaymentDCLE.SetRange(Unapplied, false);
        PaymentDCLE.SetFilter("Cust. Ledger Entry No.", '<>%1', InvoiceCLE."Entry No.");
        PaymentDCLE.SetFilter(
            "Initial Document Type", '%1|%2',
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund);
        if not PaymentDCLE.FindSet() then begin
            // Fallback for cash-discount applications: BC sets "Applied Cust. Ledger Entry No."
            // on the payment-side DCLE to the PAYMENT'S OWN entry no. (self-reference) rather
            // than the invoice CLE. In this case the invoice-side DCLE reliably carries the
            // payment CLE entry no. in its own "Applied Cust. Ledger Entry No." field — use
            // that to find the payment-side DCLE directly by "Cust. Ledger Entry No.".
            // Guard against self-references and zeros on the invoice DCLE (credit memo path).
            if (InvoiceDCLE."Applied Cust. Ledger Entry No." = 0) or
               (InvoiceDCLE."Applied Cust. Ledger Entry No." = InvoiceDCLE."Cust. Ledger Entry No.")
            then
                exit; // Credit memo or unrecognized application → Epic 5
            PaymentDCLE.Reset();
            PaymentDCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
            PaymentDCLE.SetRange("Cust. Ledger Entry No.", InvoiceDCLE."Applied Cust. Ledger Entry No.");
            PaymentDCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
            PaymentDCLE.SetRange(Unapplied, false);
            PaymentDCLE.SetFilter(
                "Initial Document Type", '%1|%2',
                "Gen. Journal Document Type"::Payment,
                "Gen. Journal Document Type"::Refund);
            if not PaymentDCLE.FindSet() then
                exit; // Still nothing → credit memo or unrecognized → Epic 5
            // In the fallback path the payment-side DCLE carries the FULL payment amount
            // (one DCLE covers all invoices in this application). Use the invoice-side DCLE
            // amount instead, which is always the exact per-invoice portion.
            IsFallbackScan := true;
        end;

        PaymentDCLECount := PaymentDCLE.Count();

        // Cash discount: BC sets "Pmt. Disc. Given (LCY)" for the whole application event.
        // When exactly one payment closes the invoice, the full discount belongs to it.
        // When multiple payments close the invoice together, the discount cannot be unambiguously
        // attributed to a single payment — pass 0 per payment to avoid inflating discount totals.
        if PaymentDCLECount = 1 then
            CashDiscountAmtLCY := GetCashDiscountAmt(InvoiceCLE)
        else
            CashDiscountAmtLCY := 0;

        // ── One set of Settlement Entries per payment ────────────────────────
        // PaymentDCLE."Amount (LCY)" is positive (this payment's contribution to closing the invoice).
        // Settlement Date = PaymentCLE."Posting Date" — when money was received, not when applied.
        // Each payment gets its own Assignment ID, grouping its line entries separately in Power BI.
        repeat
            if not PaymentCLE.Get(PaymentDCLE."Cust. Ledger Entry No.") then
                continue;
            if not (PaymentCLE."Document Type" in
                ["Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund])
            then
                continue;

            // Primary path: each payment DCLE carries the exact per-invoice cash amount.
            //   Subtract CashDiscountAmtLCY because Skonto DCLEs inflate Amount (LCY)
            //   to include the discount before the Application DCLE fires.
            // Fallback path: the payment DCLE is a self-reference with the FULL payment
            //   amount across all invoices — not usable per-invoice. Use the invoice-side
            //   DCLE amount instead, which is always the exact per-invoice portion.
            //   CashDiscountAmtLCY is still subtracted for the cash-discount single-invoice
            //   case (InvoiceDCLE amount = cash + discount on the AR side).
            if IsFallbackScan then
                PaymentAmtLCY := -InvoiceDCLE."Amount (LCY)" - CashDiscountAmtLCY
            else
                PaymentAmtLCY := PaymentDCLE."Amount (LCY)" - CashDiscountAmtLCY;
            BankLedgEntry := GetBankLedgEntryByPaymentCLE(PaymentCLE);
            AssignmentID := GenerateAssignmentID(InvoiceCLE."Customer No.", PaymentCLE."Posting Date");

            SalesInvLine.FindSet(); // Reset cursor for each payment — filters preserved from above
            CreateSalesLineEntries(
                SalesInvLine, TotalLines, InvoiceCLE, PaymentCLE."Posting Date", BankLedgEntry,
                TotalAmtExclVAT, TotalAmtInclVAT,
                PaymentAmtLCY, CashDiscountAmtLCY, AssignmentID, TransactionNo, PaymentCLE."Entry No.");

            // Overpayment: re-read payment CLE for post-application Remaining Amount.
            // PaymentCLE."Remaining Amount" < 0 = unused AR credit (e.g. paid 1,500 on 1,190 invoice).
            // Negate to store positive unallocated amount. Unallocated entry shares the same
            // Assignment ID so the full payment event stays grouped; consumed/modified in Epic 3.3.
            PaymentCLE.Get(PaymentCLE."Entry No.");
            if PaymentCLE."Remaining Amount" < 0 then
                InsertUnallocatedEntry(
                    InvoiceCLE."Customer No.", PaymentCLE, PaymentCLE."Posting Date", BankLedgEntry, AssignmentID, TransactionNo);

        until PaymentDCLE.Next() = 0;
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
        // transaction began. This procedure is always called post-commit, so throwing an error
        // here cannot roll back the application — it would only produce a misleading message.
        // Exit silently: no settlement entries are created for this application, but the
        // posting itself is unaffected. This covers edge cases where the pre-scan did not
        // detect the partial application (e.g. apply-from-invoice-CLE when BC does not
        // trigger the cash discount, leaving the invoice partially open unexpectedly).
        if not AllocContext.TryGetAllocation(InvoiceCLE."Entry No.", TempBuffer) then
            exit;
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

        // Settlement Date = the payment's own posting date when resolvable, otherwise fall
        // back to the application date (PostingDate). The fallback applies only when no
        // payment CLE could be found (PaymentCLEEntryNo = 0 after all resolution attempts).
        if PaymentCLE."Entry No." <> 0 then
            PostingDate := PaymentCLE."Posting Date";

        AssignmentID := GenerateAssignmentID(InvoiceCLE."Customer No.", PostingDate);
        CreatePartialLineEntries(TempBuffer, InvoiceCLE, PostingDate, BankLedgEntry, AssignmentID, TransactionNo, PaymentCLE."Entry No.");
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
        CrMemoCLE: Record "Cust. Ledger Entry";
    begin
        // ── Invoice partial payments ───────────────────────────────────────
        BatchLine.SetRange("Journal Template Name", GenJnlLine."Journal Template Name");
        BatchLine.SetRange("Journal Batch Name", GenJnlLine."Journal Batch Name");
        BatchLine.SetRange("Account Type", BatchLine."Account Type"::Customer);
        BatchLine.SetRange("Applies-to Doc. Type", "Gen. Journal Document Type"::Invoice);
        BatchLine.SetFilter("Applies-to Doc. No.", '<>%1', '');
        if BatchLine.FindSet() then
            repeat
                if FindInvoiceCLEForJnlLine(BatchLine, InvoiceCLE) then
                    if IsPartialApplication(BatchLine, InvoiceCLE) then
                        PreparePartialPaymentAllocation(
                            InvoiceCLE, Abs(BatchLine."Amount (LCY)"), BatchLine."Posting Date");
            until BatchLine.Next() = 0;

        // ── Credit memo partial refunds ────────────────────────────────────
        // Mirrors the invoice scan: scan for refund journal lines that partially apply
        // against a credit memo (amount < CM remaining) and open the allocation page.
        BatchLine.Reset();
        BatchLine.SetRange("Journal Template Name", GenJnlLine."Journal Template Name");
        BatchLine.SetRange("Journal Batch Name", GenJnlLine."Journal Batch Name");
        BatchLine.SetRange("Account Type", BatchLine."Account Type"::Customer);
        BatchLine.SetRange("Applies-to Doc. Type", "Gen. Journal Document Type"::"Credit Memo");
        BatchLine.SetFilter("Applies-to Doc. No.", '<>%1', '');
        if BatchLine.FindSet() then
            repeat
                if FindCrMemoCLEForJnlLine(BatchLine, CrMemoCLE) then
                    if IsPartialCrMemoApplication(BatchLine, CrMemoCLE) then
                        PreparePartialPaymentAllocation(
                            CrMemoCLE, Abs(BatchLine."Amount (LCY)"), BatchLine."Posting Date");
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
        CrMemoCLE: Record "Cust. Ledger Entry";
        ApplicationAmt: Decimal;
    begin
        if CustomerNo = '' then
            exit;

        // ── Apply-from-invoice direction ─────────────────────────────────────
        // Invoice CLE is passed directly as driving entry.
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

        // ── Apply-from-credit-memo direction ─────────────────────────────────
        // Mirrors apply-from-invoice: CM CLE is the driving entry; Refund CLEs are being applied.
        // Remaining Amount is negative for CMs; Abs() gives the outstanding balance.
        if (CustLedgEntry."Entry No." <> 0) and
           (CustLedgEntry."Document Type" = "Gen. Journal Document Type"::"Credit Memo") and
           CustLedgEntry.Open
        then begin
            CustLedgEntry.CalcFields("Remaining Amount");
            ApplicationAmt := CalcTotalRefundAmtToApply(CustomerNo);
            if (CustLedgEntry."Remaining Amount" < 0) and
               (ApplicationAmt > 0) and
               (ApplicationAmt < Abs(CustLedgEntry."Remaining Amount") - Abs(CustLedgEntry."Remaining Pmt. Disc. Possible") - 0.005)
            then begin
                PreparePartialPaymentAllocation(CustLedgEntry, ApplicationAmt, PostingDate);
                // Store the applying refund CLE entry no. so HandlePartialCrMemoSettlement can
                // resolve the bank entry (same reason as apply-from-invoice for payment CLEs).
                AllocContext.StorePaymentCLE(CustLedgEntry."Entry No.", FindApplyingRefundCLEEntryNo(CustomerNo));
            end;
            exit;
        end;

        // ── Apply-from-payment/refund direction ──────────────────────────────
        // Scan open invoice CLEs with Amount to Apply set for partial invoice payments.
        InvoiceCLE.SetRange("Customer No.", CustomerNo);
        InvoiceCLE.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        InvoiceCLE.SetRange(Open, true);
        InvoiceCLE.SetFilter("Amount to Apply", '<>0');
        if InvoiceCLE.FindSet() then
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

        // Scan open CM CLEs with Amount to Apply set for partial CM refund applications.
        // Mirrors the invoice scan above; amounts are negative so Abs() is used throughout.
        CrMemoCLE.SetRange("Customer No.", CustomerNo);
        CrMemoCLE.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
        CrMemoCLE.SetRange(Open, true);
        CrMemoCLE.SetFilter("Amount to Apply", '<>0');
        if CrMemoCLE.FindSet() then
            repeat
                CrMemoCLE.CalcFields("Remaining Amount");
                if CrMemoCLE."Remaining Amount" < 0 then begin
                    ApplicationAmt := Abs(CrMemoCLE."Amount to Apply");
                    // Same fallback logic as invoices: if Amount to Apply equals full remaining,
                    // use the Refund CLE's remaining amount as the effective applied amount.
                    if ApplicationAmt >= Abs(CrMemoCLE."Remaining Amount") - Abs(CrMemoCLE."Remaining Pmt. Disc. Possible") - 0.005 then begin
                        CustLedgEntry.CalcFields("Remaining Amount");
                        ApplicationAmt := Abs(CustLedgEntry."Remaining Amount");
                    end;
                    if (ApplicationAmt > 0) and
                       (ApplicationAmt < Abs(CrMemoCLE."Remaining Amount") - Abs(CrMemoCLE."Remaining Pmt. Disc. Possible") - 0.005)
                    then
                        PreparePartialPaymentAllocation(CrMemoCLE, ApplicationAmt, PostingDate);
                end;
            until CrMemoCLE.Next() = 0;
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

    local procedure FindCrMemoCLEForJnlLine(GenJnlLine: Record "Gen. Journal Line"; var CrMemoCLE: Record "Cust. Ledger Entry"): Boolean
    begin
        CrMemoCLE.SetRange("Customer No.", GenJnlLine."Account No.");
        CrMemoCLE.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
        CrMemoCLE.SetRange("Document No.", GenJnlLine."Applies-to Doc. No.");
        CrMemoCLE.SetRange(Open, true);
        exit(CrMemoCLE.FindFirst());
    end;

    local procedure IsPartialApplication(GenJnlLine: Record "Gen. Journal Line"; var InvoiceCLE: Record "Cust. Ledger Entry"): Boolean
    begin
        InvoiceCLE.CalcFields("Remaining Amount");
        if InvoiceCLE."Remaining Amount" <= 0 then
            exit(false);
        // Subtract "Remaining Pmt. Disc. Possible" so that a payment qualifying for cash
        // discount is not treated as partial — the discount closes the remaining gap.
        // Consistent with the threshold used in ScanForCLEPartialPayments.
        exit(Abs(GenJnlLine."Amount (LCY)") < InvoiceCLE."Remaining Amount" - InvoiceCLE."Remaining Pmt. Disc. Possible" - 0.005);
    end;

    local procedure IsPartialCrMemoApplication(GenJnlLine: Record "Gen. Journal Line"; var CrMemoCLE: Record "Cust. Ledger Entry"): Boolean
    begin
        CrMemoCLE.CalcFields("Remaining Amount");
        if CrMemoCLE."Remaining Amount" >= 0 then // CM remaining is negative when open
            exit(false);
        // Abs(refund amount) < Abs(CM remaining) - discount - epsilon → partial.
        exit(Abs(GenJnlLine."Amount (LCY)") < Abs(CrMemoCLE."Remaining Amount") - Abs(CrMemoCLE."Remaining Pmt. Disc. Possible") - 0.005);
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
        TransactionNo: Integer;
        PaymentCLEEntryNo: Integer)
    var
        Customer: Record Customer;
    begin
        Customer.Get(InvoiceCLE."Customer No.");
        // Insert an entry for every line, including 0-amount lines.
        // Consistent with CreateSalesLineEntries (full-close path): 0-amount entries provide
        // an explicit audit trail showing the line was considered and received no allocation
        // in this payment event. Absence of an entry would be ambiguous in Power BI reporting.
        if TempBuffer.FindSet() then
            repeat
                InsertPartialSalesSettlementEntry(
                    TempBuffer, InvoiceCLE, PostingDate, BankLedgEntry, Customer, AssignmentID, TransactionNo, PaymentCLEEntryNo);
            until TempBuffer.Next() = 0;
    end;

    local procedure InsertPartialSalesSettlementEntry(
        TempBuffer: Record "Pmt. Alloc. Line Buffer";
        InvoiceCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        Customer: Record Customer;
        AssignmentID: Code[50];
        TransactionNo: Integer;
        PaymentCLEEntryNo: Integer)
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
        SettlementEntry."Cash Discount Amt Incl. VAT (LCY)" := 0;
        // Cash discount is always 0 for partial payments — user allocates cash only.
        SettlementEntry."Total Settled Amt (LCY)" := LineAmt;
        SettlementEntry."Total Settled Amt Incl. VAT (LCY)" := LineAmtInclVAT;

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
        SettlementEntry."Source Payment CLE Entry No." := PaymentCLEEntryNo;
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
        SettlementEntry."Total Settled Amt (LCY)" := -PaymentCLE."Remaining Amount";
        SettlementEntry."Total Settled Amt Incl. VAT (LCY)" := -PaymentCLE."Remaining Amount";

        SettlementEntry."CV No." := CustomerNo;
        SettlementEntry."CV Name" := Customer.Name;

        SettlementEntry."Source Transaction No." := TransactionNo;
        SettlementEntry."Source Payment CLE Entry No." := PaymentCLE."Entry No.";
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

    /// <summary>
    /// Sums the absolute "Amount to Apply" of all Refund CLEs marked for application
    /// for the given customer. Used when applying FROM a credit memo CLE (apply-from-CM
    /// direction) where the CM's own "Amount to Apply" is 0 and the Refund CLEs carry
    /// the applied amounts. Refund amounts are negative; Abs() gives the positive total.
    /// </summary>
    local procedure CalcTotalRefundAmtToApply(CustomerNo: Code[20]): Decimal
    var
        RefundCLE: Record "Cust. Ledger Entry";
    begin
        RefundCLE.SetRange("Customer No.", CustomerNo);
        RefundCLE.SetRange("Document Type", "Gen. Journal Document Type"::Refund);
        RefundCLE.SetFilter("Amount to Apply", '<>0');
        RefundCLE.CalcSums("Amount to Apply");
        exit(Abs(RefundCLE."Amount to Apply"));
    end;

    /// <summary>
    /// Returns the entry no. of the first Refund CLE with "Amount to Apply" set for
    /// the given customer. Called at pre-scan time (apply-from-CM direction) to store
    /// the Refund CLE so HandlePartialCrMemoSettlement can resolve the bank entry.
    /// Returns 0 if none is found.
    /// </summary>
    local procedure FindApplyingRefundCLEEntryNo(CustomerNo: Code[20]): Integer
    var
        RefundCLE: Record "Cust. Ledger Entry";
    begin
        RefundCLE.SetRange("Customer No.", CustomerNo);
        RefundCLE.SetRange("Document Type", "Gen. Journal Document Type"::Refund);
        RefundCLE.SetFilter("Amount to Apply", '<>0');
        if RefundCLE.FindFirst() then
            exit(RefundCLE."Entry No.");
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
    /// Returns true if Settlement Entries were already created for the given
    /// (Transaction No., Payment CLE Entry No.) pair.
    /// Scoping by both fields allows multiple payments applied to the same invoice in one
    /// session (all sharing the same Transaction No.) to each produce their own entries,
    /// while still blocking the invoice-side and payment-side DCLEs from double-processing
    /// the same individual payment application.
    /// When TransactionNo = 0 (CLE apply path), the guard is intentionally bypassed —
    /// the HandledInvoiceCLEs list in ProcessNewApplicationDCLEs provides dedup in that path.
    /// </summary>
    local procedure SettlementEntriesExistForTransaction(TransactionNo: Integer; PaymentCLEEntryNo: Integer): Boolean
    var
        ExistingEntry: Record "Settlement Entry";
    begin
        if TransactionNo = 0 then
            exit(false);
        ExistingEntry.SetRange("Source Transaction No.", TransactionNo);
        ExistingEntry.SetRange("Source Payment CLE Entry No.", PaymentCLEEntryNo);
        exit(not ExistingEntry.IsEmpty());
    end;

    // ── Public: already-settled amount lookup ────────────────────────────────

    /// <summary>
    /// Returns the net already-settled amount (incl. VAT, LCY) for a specific invoice line.
    /// Sums ALL Settlement Entries for the given document + line — including reversal entries,
    /// which carry negative amounts and therefore cancel their originals in the net.
    /// Caller does not need to distinguish between active and reversed entries.
    /// </summary>
    procedure GetAlreadySettledAmtInclVAT(DocumentNo: Code[20]; DocumentLineNo: Integer): Decimal
    var
        SettlementEntry: Record "Settlement Entry";
    begin
        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        SettlementEntry.SetRange("Document No.", DocumentNo);
        SettlementEntry.SetRange("Document Line No.", DocumentLineNo);
        // Sum "Total Settled Amt Incl. VAT (LCY)" which includes cash discount incl. VAT,
        // so that a prior cash-discounted payment correctly reduces the remaining distributable
        // amount for subsequent partial payments on the same line.
        SettlementEntry.CalcSums("Total Settled Amt Incl. VAT (LCY)");
        exit(SettlementEntry."Total Settled Amt Incl. VAT (LCY)");
    end;

    // ── Public: Epic 5 — Reversals ───────────────────────────────────────────

    /// <summary>
    /// Called from EventSubscriber when a customer ledger application is unapplied.
    /// The DCLE passed is the Application DCLE that was marked Unapplied = true.
    /// Identifies the invoice and the payment from the DCLE fields, then creates
    /// reversal Settlement Entries for all non-reversed entries of that application.
    /// Fires twice for full-payment applications (once per side) — the second fire
    /// finds nothing to reverse (originals already marked Reversed = true) and exits.
    /// Only invoice-side and payment-side DCLEs are handled; other types are ignored.
    /// </summary>
    procedure CreateReversalEntriesForUnapplication(UnappliedDCLE: Record "Detailed Cust. Ledg. Entry")
    var
        InvoiceCLE: Record "Cust. Ledger Entry";
        DocumentNo: Code[20];
        PaymentCLEEntryNo: Integer;
    begin
        if UnappliedDCLE."Entry Type" <> "Detailed CV Ledger Entry Type"::Application then
            exit;
        // Note: do NOT check UnappliedDCLE.Unapplied here.
        // OnAfterPostUnapplyCustLedgEntry fires from PostUnApplyCustomerCommit BEFORE Commit —
        // the Unapplied = true write is in-flight in the same transaction, but the DCLE record
        // variable passed to the event may still show Unapplied = false. The event name and
        // Entry Type = Application are the only guards needed.

        case UnappliedDCLE."Initial Document Type" of
            "Gen. Journal Document Type"::Invoice:
                begin
                    // Invoice-side DCLE: "Cust. Ledger Entry No." = invoice CLE
                    if not InvoiceCLE.Get(UnappliedDCLE."Cust. Ledger Entry No.") then
                        exit;
                    DocumentNo := InvoiceCLE."Document No.";
                    // "Applied Cust. Ledger Entry No." = the payment CLE that closed the invoice.
                    // May be 0 for cash-discount self-reference — treated as "reverse all" below.
                    PaymentCLEEntryNo := UnappliedDCLE."Applied Cust. Ledger Entry No.";
                    if PaymentCLEEntryNo = InvoiceCLE."Entry No." then
                        PaymentCLEEntryNo := 0; // self-reference guard
                end;
            "Gen. Journal Document Type"::"Credit Memo":
                begin
                    // Credit memo DCLE: "Cust. Ledger Entry No." = credit memo CLE.
                    // "Applied Cust. Ledger Entry No." = the Refund CLE that applied to the CM.
                    // Settlement entries store the Refund CLE entry no. as "Source Payment CLE Entry No."
                    // (consistent with invoice pattern) — pass it as PaymentCLEEntryNo so that
                    // ReverseDocumentEntries finds both full and partial CM settlement entries.
                    if not InvoiceCLE.Get(UnappliedDCLE."Cust. Ledger Entry No.") then
                        exit;
                    if InvoiceCLE."Document Type" <> "Gen. Journal Document Type"::"Credit Memo" then
                        exit;
                    DocumentNo := InvoiceCLE."Document No.";
                    PaymentCLEEntryNo := UnappliedDCLE."Applied Cust. Ledger Entry No.";
                    if PaymentCLEEntryNo = InvoiceCLE."Entry No." then
                        PaymentCLEEntryNo := 0; // self-reference guard
                end;
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund:
                begin
                    // Payment/Refund-side DCLE: "Cust. Ledger Entry No." is always the payment CLE.
                    // "Applied Cust. Ledger Entry No." should be the invoice CLE, but BC may
                    // leave it as 0 or as a self-reference for partial payments (apply-from-invoice
                    // direction). In those cases we fall back to a payment-CLE-only filter —
                    // DocumentNo stays '' and ReverseDocumentEntries skips the document filter.
                    // For refunds applied to credit memos: Applied CLE is the CM CLE — not an invoice,
                    // so DocumentNo stays '' and no entries are found (CM reversal is handled by the
                    // Credit Memo case above when that DCLE fires).
                    PaymentCLEEntryNo := UnappliedDCLE."Cust. Ledger Entry No.";
                    if (UnappliedDCLE."Applied Cust. Ledger Entry No." <> 0) and
                       (UnappliedDCLE."Applied Cust. Ledger Entry No." <> UnappliedDCLE."Cust. Ledger Entry No.")
                    then
                        if InvoiceCLE.Get(UnappliedDCLE."Applied Cust. Ledger Entry No.") then
                            if InvoiceCLE."Document Type" = "Gen. Journal Document Type"::Invoice then
                                DocumentNo := InvoiceCLE."Document No.";
                    // DocumentNo may still be '' here — ReverseDocumentEntries handles that.
                end;
            else
                exit;
        end;

        ReverseDocumentEntries(DocumentNo, PaymentCLEEntryNo, UnappliedDCLE."Posting Date");
    end;



    // ── Private: reversal core ───────────────────────────────────────────────

    /// <summary>
    /// Finds all non-reversed, non-reversal Settlement Entries for DocumentNo (invoice or CM)
    /// and creates a reversal entry for each. When PaymentCLEEntryNo is non-zero, the search
    /// is narrowed to entries from that specific payment/refund application (unapply scenario).
    /// When PaymentCLEEntryNo = 0, all entries for the document are reversed (cancellation).
    /// Fallback: if PaymentCLEEntryNo is set but finds no matches, retries with Document No.
    /// only — guards against rare cases where the stored Source Payment CLE does not match the
    /// unapplication DCLE's Applied CLE (e.g. BC self-references on CM-side DCLEs).
    /// Uses FindSet(true) to hold write locks throughout the modify-during-iteration loop.
    /// </summary>
    local procedure ReverseDocumentEntries(DocumentNo: Code[20]; PaymentCLEEntryNo: Integer; PostingDate: Date)
    var
        OriginalEntry: Record "Settlement Entry";
    begin
        // Require at least one filter to avoid accidentally reversing unrelated entries.
        if (DocumentNo = '') and (PaymentCLEEntryNo = 0) then
            exit;
        SetReverseDocumentFilters(OriginalEntry, DocumentNo, PaymentCLEEntryNo);
        // FindSet(true) = write-locked cursor — required because CreateReversalEntry calls
        // OriginalEntry.Modify() inside the loop (sets Reversed = true). Without the write
        // lock, modifying a filtered field mid-iteration can cause the cursor to skip records.
        if not OriginalEntry.FindSet(true) then begin
            // Fallback: if the specific Source Payment CLE filter found nothing and we have
            // a known Document No., retry without the CLE filter. This handles rare scenarios
            // where the unapplication DCLE's "Applied CLE" does not match the Source Payment
            // CLE stored in the forward entries (e.g. BC self-reference on CM-side DCLE).
            // Only safe when DocumentNo is set — prevents too-broad reversals.
            if (PaymentCLEEntryNo = 0) or (DocumentNo = '') then
                exit;
            SetReverseDocumentFilters(OriginalEntry, DocumentNo, 0);
            if not OriginalEntry.FindSet(true) then
                exit;
        end;
        repeat
            CreateReversalEntry(OriginalEntry, PostingDate);
        until OriginalEntry.Next() = 0;
    end;

    local procedure SetReverseDocumentFilters(var OriginalEntry: Record "Settlement Entry"; DocumentNo: Code[20]; PaymentCLEEntryNo: Integer)
    begin
        OriginalEntry.Reset();
        OriginalEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        // DocumentNo = '' means the payment-side DCLE could not resolve the invoice —
        // skip the document filter and rely solely on Source Payment CLE Entry No.
        if DocumentNo <> '' then
            OriginalEntry.SetRange("Document No.", DocumentNo);
        OriginalEntry.SetRange("Reversal Entry", false);
        OriginalEntry.SetRange(Reversed, false);
        if PaymentCLEEntryNo <> 0 then
            OriginalEntry.SetRange("Source Payment CLE Entry No.", PaymentCLEEntryNo);
    end;

    /// <summary>
    /// Creates one reversal Settlement Entry mirroring OriginalEntry with negated amounts.
    /// Sets Reversal Entry = true and Original Entry No. on the new entry.
    /// Marks the original entry Reversed = true and sets its Reversal Entry No.
    /// Calls UpdateSalesInvLineOutstandingAmt so Outstanding Amt and fully-settled
    /// flags stay in sync after the reversal.
    /// </summary>
    local procedure CreateReversalEntry(var OriginalEntry: Record "Settlement Entry"; PostingDate: Date)
    var
        ReversalEntry: Record "Settlement Entry";
    begin
        ReversalEntry.Init();
        ReversalEntry."Transaction Type" := OriginalEntry."Transaction Type";
        ReversalEntry."Document Type" := OriginalEntry."Document Type";
        ReversalEntry."Settlement Entry Type" := "Settlement Entry Type"::Reversal;
        ReversalEntry."Document No." := OriginalEntry."Document No.";
        ReversalEntry."Document Line No." := OriginalEntry."Document Line No.";

        ReversalEntry."Assignment ID" := GenerateAssignmentID(OriginalEntry."CV No.", PostingDate);
        ReversalEntry."Settlement Date" := PostingDate;

        // Negate all amount fields — reversal carries exactly opposite signs.
        ReversalEntry."Settlement Amt (LCY)" := -OriginalEntry."Settlement Amt (LCY)";
        ReversalEntry."Settlement Amt Incl. VAT (LCY)" := -OriginalEntry."Settlement Amt Incl. VAT (LCY)";
        ReversalEntry."Cash Discount Amt (LCY)" := -OriginalEntry."Cash Discount Amt (LCY)";
        ReversalEntry."Cash Discount Amt Incl. VAT (LCY)" := -OriginalEntry."Cash Discount Amt Incl. VAT (LCY)";
        ReversalEntry."Total Settled Amt (LCY)" := -OriginalEntry."Total Settled Amt (LCY)";
        ReversalEntry."Total Settled Amt Incl. VAT (LCY)" := -OriginalEntry."Total Settled Amt Incl. VAT (LCY)";

        // Snapshots stay unchanged — they represent the original billed amounts, not the reversal.
        ReversalEntry."Original Line Amt (LCY)" := OriginalEntry."Original Line Amt (LCY)";
        ReversalEntry."Orig. Line Amt Incl. VAT (LCY)" := OriginalEntry."Orig. Line Amt Incl. VAT (LCY)";
        ReversalEntry."Non-Deductible VAT Amt (LCY)" := OriginalEntry."Non-Deductible VAT Amt (LCY)";

        ReversalEntry."Bank Statement Document No." := OriginalEntry."Bank Statement Document No.";
        ReversalEntry."CV No." := OriginalEntry."CV No.";
        ReversalEntry."CV Name" := OriginalEntry."CV Name";

        ReversalEntry."Global Dimension 1 Code" := OriginalEntry."Global Dimension 1 Code";
        ReversalEntry."Global Dimension 2 Code" := OriginalEntry."Global Dimension 2 Code";
        ReversalEntry."Shortcut Dimension 3 Code" := OriginalEntry."Shortcut Dimension 3 Code";
        ReversalEntry."Shortcut Dimension 4 Code" := OriginalEntry."Shortcut Dimension 4 Code";
        ReversalEntry."Shortcut Dimension 5 Code" := OriginalEntry."Shortcut Dimension 5 Code";
        ReversalEntry."Shortcut Dimension 6 Code" := OriginalEntry."Shortcut Dimension 6 Code";
        ReversalEntry."Shortcut Dimension 7 Code" := OriginalEntry."Shortcut Dimension 7 Code";
        ReversalEntry."Shortcut Dimension 8 Code" := OriginalEntry."Shortcut Dimension 8 Code";
        ReversalEntry."Dimension Set ID" := OriginalEntry."Dimension Set ID";

        ReversalEntry."G/L Account No." := OriginalEntry."G/L Account No.";
        ReversalEntry."G/L Account Name" := OriginalEntry."G/L Account Name";
        ReversalEntry."Grant Number" := OriginalEntry."Grant Number";
        ReversalEntry.Description := OriginalEntry.Description;

        // Reversal-specific tracking fields.
        ReversalEntry."Reversal Entry" := true;
        ReversalEntry."Original Entry No." := OriginalEntry."Entry No.";

        ReversalEntry."Source Transaction No." := OriginalEntry."Source Transaction No.";
        ReversalEntry."Source Payment CLE Entry No." := OriginalEntry."Source Payment CLE Entry No.";
        ReversalEntry."Created By" := CopyStr(UserId(), 1, MaxStrLen(ReversalEntry."Created By"));
        ReversalEntry."Created DateTime" := CurrentDateTime();

        ReversalEntry.Insert(true);

        // Back-link: mark original as reversed and store the reversal entry no.
        OriginalEntry.Reversed := true;
        OriginalEntry."Reversal Entry No." := ReversalEntry."Entry No.";
        OriginalEntry.Modify();

        // Update Outstanding Amt and fully-settled flags for the affected document line.
        case OriginalEntry."Document Type" of
            "Gen. Journal Document Type"::Invoice:
                UpdateSalesInvLineOutstandingAmtByLineNo(OriginalEntry."Document No.", OriginalEntry."Document Line No.");
            "Gen. Journal Document Type"::"Credit Memo":
                UpdateSalesCrMemoLineOutstandingAmtByLineNo(OriginalEntry."Document No.", OriginalEntry."Document Line No.");
        end;
    end;

    // ── Public: Epic 5 — Credit Memos ───────────────────────────────────────

    /// <summary>
    /// Called from ProcessNewApplicationDCLEs when a credit memo CLE is fully closed.
    /// Mirrors ProcessInvoiceCLEForSettlement: scans ALL refund-side Application DCLEs for
    /// this CM within the current batch and creates one set of Settlement Entries per refund,
    /// distributing each refund's amount proportionally across CM lines based on their
    /// remaining (not yet settled) balance — so that a closing refund after a prior partial
    /// settlement only covers what is still outstanding.
    /// Cash discount is applied only when exactly one refund closes the CM (like invoices).
    /// </summary>
    procedure CreateCreditMemoSettlementEntries(CrMemoDCLE: Record "Detailed Cust. Ledg. Entry"; PostingDate: Date; BaselineDCLEEntryNo: Integer)
    var
        CrMemoCLE: Record "Cust. Ledger Entry";
        RefundDCLE: Record "Detailed Cust. Ledg. Entry";
        RefundCLE: Record "Cust. Ledger Entry";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        BankLedgEntry: Record "Bank Account Ledger Entry";
        Customer: Record Customer;
        AssignmentID: Code[50];
        TotalAmtExclVAT: Decimal;
        TotalAmtInclVAT: Decimal;
        TotalLines: Integer;
        CashDiscountAmtLCY: Decimal;
        RefundAmtLCY: Decimal;
        RefundDCLECount: Integer;
    begin
        if not CrMemoCLE.Get(CrMemoDCLE."Cust. Ledger Entry No.") then
            exit;
        if CrMemoCLE."Document Type" <> "Gen. Journal Document Type"::"Credit Memo" then
            exit;
        if CrMemoCLE.Open then
            exit;

        SalesCrMemoLine.SetRange("Document No.", CrMemoCLE."Document No.");
        SalesCrMemoLine.SetFilter(Amount, '<>0');
        if SalesCrMemoLine.IsEmpty() then
            exit;
        TotalLines := SalesCrMemoLine.Count();
        if SalesCrMemoLine.FindSet() then
            repeat
                TotalAmtExclVAT += SalesCrMemoLine.Amount;
                TotalAmtInclVAT += SalesCrMemoLine."Amount Including VAT";
            until SalesCrMemoLine.Next() = 0;
        if TotalAmtInclVAT = 0 then
            exit;

        if not Customer.Get(CrMemoCLE."Customer No.") then
            exit;

        // ── Find all refund-side Application DCLEs for this CM ───────────────
        // Mirrors the invoice path: scan refund-side DCLEs whose Applied CLE = this CM CLE.
        RefundDCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
        RefundDCLE.SetRange("Applied Cust. Ledger Entry No.", CrMemoCLE."Entry No.");
        RefundDCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        RefundDCLE.SetRange(Unapplied, false);
        RefundDCLE.SetFilter("Initial Document Type", '%1|%2',
            "Gen. Journal Document Type"::Payment,
            "Gen. Journal Document Type"::Refund);
        if not RefundDCLE.FindSet() then begin
            // Fallback for Skonto / CD applications where BC uses self-referencing Applied CLE:
            // use the Refund CLE resolved directly from the CM-side DCLE.
            if (CrMemoDCLE."Applied Cust. Ledger Entry No." = 0) or
               (CrMemoDCLE."Applied Cust. Ledger Entry No." = CrMemoDCLE."Cust. Ledger Entry No.")
            then
                exit;
            RefundDCLE.Reset();
            RefundDCLE.SetFilter("Entry No.", '>%1', BaselineDCLEEntryNo);
            RefundDCLE.SetRange("Cust. Ledger Entry No.", CrMemoDCLE."Applied Cust. Ledger Entry No.");
            RefundDCLE.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
            RefundDCLE.SetRange(Unapplied, false);
            RefundDCLE.SetFilter("Initial Document Type", '%1|%2',
                "Gen. Journal Document Type"::Payment,
                "Gen. Journal Document Type"::Refund);
            if not RefundDCLE.FindSet() then
                exit;
        end;

        RefundDCLECount := RefundDCLE.Count();

        // Cash discount: only when exactly one refund closes the CM — cannot unambiguously
        // split a discount across multiple simultaneous refunds (mirrors invoice behaviour).
        if RefundDCLECount = 1 then
            CashDiscountAmtLCY := -CrMemoCLE."Pmt. Disc. Given (LCY)"
        else
            CashDiscountAmtLCY := 0;

        // ── One set of Settlement Entries per refund ─────────────────────────
        RefundDCLE.FindSet();
        repeat
            if not RefundCLE.Get(RefundDCLE."Cust. Ledger Entry No.") then
                continue;
            if not (RefundCLE."Document Type" in
                ["Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund])
            then
                continue;

            // Dedup: skip if entries already created for this (transaction, refund CLE) pair.
            if SettlementEntriesExistForTransaction(CrMemoDCLE."Transaction No.", RefundCLE."Entry No.") then
                continue;

            // Refund amount for this application: negate the refund-side DCLE then subtract discount.
            // Sign asymmetry vs. the invoice path: for Invoice+Payment the payment-side DCLE
            // Amount is POSITIVE (it reduces the payment's negative balance toward 0), so it can
            // be used directly. For CM+Refund the refund-side DCLE Amount is NEGATIVE (it reduces
            // the refund's positive balance toward 0), so it must be negated first.
            // BC inflates the DCLE Amount to include the discount effect — same as invoices.
            RefundAmtLCY := -RefundDCLE."Amount (LCY)" - CashDiscountAmtLCY;

            BankLedgEntry := GetBankLedgEntryByPaymentCLE(RefundCLE);
            if BankLedgEntry."Entry No." = 0 then
                BankLedgEntry := GetBankLedgEntryByTransactionNo(CrMemoDCLE."Transaction No.");

            AssignmentID := GenerateAssignmentID(CrMemoCLE."Customer No.", PostingDate);

            SalesCrMemoLine.FindSet(); // reset cursor — filters preserved from above
            CreateCreditMemoLineEntries(
                SalesCrMemoLine, TotalLines, CrMemoCLE, PostingDate, BankLedgEntry, Customer,
                TotalAmtExclVAT, TotalAmtInclVAT,
                RefundAmtLCY, CashDiscountAmtLCY, AssignmentID, CrMemoDCLE."Transaction No.", RefundCLE."Entry No.");
        until RefundDCLE.Next() = 0;
    end;

    /// <summary>
    /// Distributes one refund's amount proportionally across all non-zero CM lines,
    /// accounting for amounts already settled by prior entries (partial payments or
    /// earlier refunds in the same batch). Mirrors CreateSalesLineEntries for invoices.
    /// TotalLines and the SalesCrMemoLine cursor (filters set, FindSet already called)
    /// are provided by the caller to avoid duplicate queries.
    /// </summary>
    local procedure CreateCreditMemoLineEntries(
        var SalesCrMemoLine: Record "Sales Cr.Memo Line";
        TotalLines: Integer;
        CrMemoCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        Customer: Record Customer;
        TotalAmtExclVAT: Decimal;
        TotalAmtInclVAT: Decimal;
        RefundAmtLCY: Decimal;
        CashDiscountAmtLCY: Decimal;
        AssignmentID: Code[50];
        TransactionNo: Integer;
        PaymentCLEEntryNo: Integer)
    var
        SalesCrMemoLine2: Record "Sales Cr.Memo Line";
        TotalRemainingInclVAT: Decimal;
        LineCount: Integer;
        LineRemainingInclVAT: Decimal;
        LineAmtInclVAT: Decimal;
        LineAmt: Decimal;
        LineDiscount: Decimal;
        RemainingAmt: Decimal;
        RemainingAmtInclVAT: Decimal;
        RemainingDiscount: Decimal;
    begin
        // Pre-pass: compute total remaining (original minus already settled) across all lines.
        // Lines with prior partial settlements contribute only their outstanding share,
        // ensuring the proportional distribution reflects what each line still needs.
        // CalcFields / CalcSums see entries inserted earlier in the same transaction, so
        // multiple simultaneous refunds processed sequentially each get their own correct share.
        SalesCrMemoLine2.SetRange("Document No.", CrMemoCLE."Document No.");
        SalesCrMemoLine2.SetFilter(Amount, '<>0');
        if SalesCrMemoLine2.FindSet() then
            repeat
                TotalRemainingInclVAT +=
                    SalesCrMemoLine2."Amount Including VAT" -
                    GetAlreadySettledCrMemoAmtInclVAT(SalesCrMemoLine2."Document No.", SalesCrMemoLine2."Line No.");
            until SalesCrMemoLine2.Next() = 0;
        // Fallback: no prior partial settlements — use original total (first / only refund).
        if TotalRemainingInclVAT <= 0 then
            TotalRemainingInclVAT := TotalAmtInclVAT;

        RemainingAmt := Round(RefundAmtLCY * TotalAmtExclVAT / TotalAmtInclVAT);
        RemainingAmtInclVAT := RefundAmtLCY;
        RemainingDiscount := Round(CashDiscountAmtLCY * TotalAmtExclVAT / TotalAmtInclVAT);

        repeat
            LineCount += 1;
            if LineCount = TotalLines then begin
                LineAmt := RemainingAmt;
                LineAmtInclVAT := RemainingAmtInclVAT;
                LineDiscount := RemainingDiscount;
            end else begin
                // Distribute proportionally to each line's remaining (original minus already settled).
                LineRemainingInclVAT :=
                    SalesCrMemoLine."Amount Including VAT" -
                    GetAlreadySettledCrMemoAmtInclVAT(SalesCrMemoLine."Document No.", SalesCrMemoLine."Line No.");
                LineAmtInclVAT := Round(LineRemainingInclVAT * RefundAmtLCY / TotalRemainingInclVAT);
                if SalesCrMemoLine."Amount Including VAT" <> 0 then
                    LineAmt := Round(LineAmtInclVAT * SalesCrMemoLine.Amount / SalesCrMemoLine."Amount Including VAT")
                else
                    LineAmt := LineAmtInclVAT;
                // Distribute cash discount proportionally to each line's excl. VAT amount.
                LineDiscount := Round(SalesCrMemoLine.Amount * CashDiscountAmtLCY / TotalAmtInclVAT);
                RemainingAmt -= LineAmt;
                RemainingAmtInclVAT -= LineAmtInclVAT;
                RemainingDiscount -= LineDiscount;
            end;

            InsertCreditMemoSettlementEntry(
                SalesCrMemoLine, CrMemoCLE, PostingDate, BankLedgEntry, Customer,
                AssignmentID, TransactionNo, PaymentCLEEntryNo,
                LineAmt, LineAmtInclVAT, LineDiscount);
        until SalesCrMemoLine.Next() = 0;
    end;

    local procedure InsertCreditMemoSettlementEntry(
        var SalesCrMemoLine: Record "Sales Cr.Memo Line";
        CrMemoCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        Customer: Record Customer;
        AssignmentID: Code[50];
        TransactionNo: Integer;
        PaymentCLEEntryNo: Integer;
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
        LineCashDiscountLCY: Decimal)
    var
        SettlementEntry: Record "Settlement Entry";
        GLAccount: Record "G/L Account";
        LineCashDiscountInclVATLCY: Decimal;
    begin
        // Back-calculate cash discount incl. VAT using the line's VAT ratio.
        if SalesCrMemoLine.Amount <> 0 then
            LineCashDiscountInclVATLCY :=
                Round(LineCashDiscountLCY * SalesCrMemoLine."Amount Including VAT" / SalesCrMemoLine.Amount)
        else
            LineCashDiscountInclVATLCY := LineCashDiscountLCY;

        SettlementEntry.Init();

        SettlementEntry."Transaction Type" := "Settlement Transaction Type"::Sales;
        SettlementEntry."Document Type" := "Gen. Journal Document Type"::"Credit Memo";
        SettlementEntry."Document No." := SalesCrMemoLine."Document No.";
        SettlementEntry."Document Line No." := SalesCrMemoLine."Line No.";

        SettlementEntry."Assignment ID" := AssignmentID;
        SettlementEntry."Settlement Date" := PostingDate;
        // Mirrors the invoice pattern exactly:
        //   Settlement Amt    = actual cash refunded (LineAmt, already net of discount because
        //                       RefundAmtLCY = -RefundDCLE."Amount (LCY)" - CashDiscountAmtLCY).
        //   Cash Discount Amt = the discount portion stored separately.
        //   Total Settled Amt = Settlement + Discount = full line amount — closes the CM line.
        SettlementEntry."Settlement Amt (LCY)" := LineAmt;
        SettlementEntry."Settlement Amt Incl. VAT (LCY)" := LineAmtInclVAT;
        SettlementEntry."Cash Discount Amt (LCY)" := LineCashDiscountLCY;
        SettlementEntry."Cash Discount Amt Incl. VAT (LCY)" := LineCashDiscountInclVATLCY;
        SettlementEntry."Total Settled Amt (LCY)" := LineAmt + LineCashDiscountLCY;
        SettlementEntry."Total Settled Amt Incl. VAT (LCY)" := LineAmtInclVAT + LineCashDiscountInclVATLCY;

        SettlementEntry."Original Line Amt (LCY)" := SalesCrMemoLine.Amount;
        SettlementEntry."Orig. Line Amt Incl. VAT (LCY)" := SalesCrMemoLine."Amount Including VAT";

        SettlementEntry."Bank Statement Document No." := BankLedgEntry."Document No.";
        SettlementEntry."CV No." := CrMemoCLE."Customer No.";
        SettlementEntry."CV Name" := Customer.Name;

        SettlementEntry."Global Dimension 1 Code" := SalesCrMemoLine."Shortcut Dimension 1 Code";
        SettlementEntry."Global Dimension 2 Code" := SalesCrMemoLine."Shortcut Dimension 2 Code";
        SettlementEntry."Dimension Set ID" := SalesCrMemoLine."Dimension Set ID";
        PopulateShortcutDimensions(SettlementEntry, SalesCrMemoLine."Dimension Set ID");

        if SalesCrMemoLine.Type = SalesCrMemoLine.Type::"G/L Account" then begin
            SettlementEntry."G/L Account No." := SalesCrMemoLine."No.";
            if GLAccount.Get(SalesCrMemoLine."No.") then
                SettlementEntry."G/L Account Name" := GLAccount.Name;
        end;

        SettlementEntry.Description :=
            CopyStr(SalesCrMemoLine.Description, 1, MaxStrLen(SettlementEntry.Description));

        SettlementEntry."Source Transaction No." := TransactionNo;
        SettlementEntry."Source Payment CLE Entry No." := PaymentCLEEntryNo;
        SettlementEntry."Created By" := CopyStr(UserId(), 1, MaxStrLen(SettlementEntry."Created By"));
        SettlementEntry."Created DateTime" := CurrentDateTime();

        SettlementEntry.Insert(true);

        // Update Outstanding Amt and fully-settled flags for the affected credit memo line.
        UpdateSalesCrMemoLineOutstandingAmt(SalesCrMemoLine);
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
        TransactionNo: Integer;
        PaymentCLEEntryNo: Integer)
    var
        SalesInvLine2: Record "Sales Invoice Line";
        Customer: Record Customer;
        LineCount: Integer;
        RemainingAmt: Decimal;
        RemainingAmtInclVAT: Decimal;
        RemainingDiscount: Decimal;
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
        LineDiscount: Decimal;
        LineRemainingInclVAT: Decimal;
        TotalRemainingInclVAT: Decimal;
    begin
        Customer.Get(InvoiceCLE."Customer No.");

        // Pre-pass: compute total remaining incl. VAT across all lines.
        // Lines with prior partial payments contribute only their unallocated share,
        // ensuring the proportional distribution reflects what each line still needs.
        // This also fixes the miscalculation when the second partial payment closes the invoice.
        SalesInvLine2.SetRange("Document No.", InvoiceCLE."Document No.");
        SalesInvLine2.SetFilter(Amount, '<>0');
        if SalesInvLine2.FindSet() then
            repeat
                TotalRemainingInclVAT +=
                    SalesInvLine2."Amount Including VAT" -
                    GetAlreadySettledAmtInclVAT(SalesInvLine2."Document No.", SalesInvLine2."Line No.");
            until SalesInvLine2.Next() = 0;
        // Fallback: no prior partial payments — use original total (first payment, full settlement).
        if TotalRemainingInclVAT = 0 then
            TotalRemainingInclVAT := TotalAmtInclVAT;

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
                // Distribute proportionally to each line's remaining (original minus already settled).
                LineRemainingInclVAT :=
                    SalesInvLine."Amount Including VAT" -
                    GetAlreadySettledAmtInclVAT(SalesInvLine."Document No.", SalesInvLine."Line No.");
                LineAmtInclVAT := Round(LineRemainingInclVAT * PaymentAmtLCY / TotalRemainingInclVAT);
                if SalesInvLine."Amount Including VAT" <> 0 then
                    LineAmt := Round(LineAmtInclVAT * SalesInvLine.Amount / SalesInvLine."Amount Including VAT")
                else
                    LineAmt := LineAmtInclVAT;
                // Distribute the excl. VAT cash discount proportionally to each line's excl. VAT amount.
                // Using SalesInvLine.Amount (excl. VAT) / TotalAmtInclVAT gives the correct excl. VAT
                // share per line — consistent with how RemainingDiscount is initialised.
                // Example: 3 equal lines, CashDiscount=107.10 (incl. VAT), TotalInclVAT=3570:
                //   Round(1000 * 107.10 / 3570) = 30.00 per line  ✓  (not 35.70 from incl./incl.)
                LineDiscount := Round(SalesInvLine.Amount * CashDiscountAmtLCY / TotalAmtInclVAT);
                RemainingAmt -= LineAmt;
                RemainingAmtInclVAT -= LineAmtInclVAT;
                RemainingDiscount -= LineDiscount;
            end;

            InsertSalesSettlementEntry(
                SalesInvLine, InvoiceCLE, PostingDate, BankLedgEntry, Customer,
                AssignmentID, TransactionNo, PaymentCLEEntryNo, LineAmt, LineAmtInclVAT, LineDiscount);

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
        PaymentCLEEntryNo: Integer;
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
        // Cash discount incl. VAT: back-calculate from excl. VAT using line VAT ratio.
        if SalesInvLine.Amount <> 0 then
            SettlementEntry."Cash Discount Amt Incl. VAT (LCY)" :=
                Round(LineDiscount * SalesInvLine."Amount Including VAT" / SalesInvLine.Amount)
        else
            SettlementEntry."Cash Discount Amt Incl. VAT (LCY)" := LineDiscount;
        SettlementEntry."Total Settled Amt (LCY)" := LineAmt + LineDiscount;
        SettlementEntry."Total Settled Amt Incl. VAT (LCY)" :=
            LineAmtInclVAT + SettlementEntry."Cash Discount Amt Incl. VAT (LCY)";

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
        SettlementEntry."Source Payment CLE Entry No." := PaymentCLEEntryNo;
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

    // ── Public: already-settled amount lookup (Credit Memo) ─────────────────────

    /// <summary>
    /// Returns the net already-settled amount (incl. VAT, LCY, absolute value) for a
    /// specific credit memo line. Sums ALL Settlement Entries including reversals (which
    /// cancel their originals). Returns absolute value so the allocation page can use the
    /// same positive-value logic as for invoice lines.
    /// </summary>
    procedure GetAlreadySettledCrMemoAmtInclVAT(DocumentNo: Code[20]; DocumentLineNo: Integer): Decimal
    var
        SettlementEntry: Record "Settlement Entry";
    begin
        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
        SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        SettlementEntry.SetRange("Document No.", DocumentNo);
        SettlementEntry.SetRange("Document Line No.", DocumentLineNo);
        SettlementEntry.CalcSums("Total Settled Amt Incl. VAT (LCY)");
        // CM forward entries carry positive Total Settled Amt (SalesCrMemoLine.Amount is positive).
        // Reversal entries carry negative amounts. Net = forward - reversal = outstanding portion.
        // Abs() ensures the result is always a non-negative magnitude for the caller.
        exit(Abs(SettlementEntry."Total Settled Amt Incl. VAT (LCY)"));
    end;

    // ── Private: partial CM settlement ──────────────────────────────────────────

    /// <summary>
    /// Called from ProcessNewApplicationDCLEs (CM DCLE loop) and HandlePaymentApplicationDCLE
    /// (Refund DCLE safety net) when a CM CLE is partially settled (remains Open after
    /// the refund application). Mirrors HandlePartialPayment for invoices.
    /// Reads the pre-collected allocation from Pmt. Alloc. Context, then creates
    /// Settlement Entries for each CM line.
    /// </summary>
    local procedure HandlePartialCrMemoSettlement(CrMemoCLE: Record "Cust. Ledger Entry"; PostingDate: Date; TransactionNo: Integer; RefundCLEEntryNo: Integer)
    var
        AllocContext: Codeunit "Pmt. Alloc. Context";
        TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary;
        RefundCLE: Record "Cust. Ledger Entry";
        BankLedgEntry: Record "Bank Account Ledger Entry";
        AssignmentID: Code[50];
    begin
        // Allocation must have been pre-collected by ScanBatchForPartialPayments or
        // ScanForCLEPartialPayments before the write transaction. Exit silently if missing —
        // mirrors HandlePartialPayment behaviour (no rollback possible post-commit).
        if not AllocContext.TryGetAllocation(CrMemoCLE."Entry No.", TempBuffer) then
            exit;
        AllocContext.ClearAllocation(CrMemoCLE."Entry No.");
        if TempBuffer.IsEmpty() then
            exit;

        // Resolve the Refund CLE for bank entry lookup.
        // For apply-from-CM direction, the Refund CLE was stored at pre-scan time.
        if (RefundCLEEntryNo = 0) or (RefundCLEEntryNo = CrMemoCLE."Entry No.") then
            RefundCLEEntryNo := AllocContext.GetPaymentCLE(CrMemoCLE."Entry No.");
        AllocContext.ClearPaymentCLE(CrMemoCLE."Entry No.");

        if RefundCLEEntryNo <> 0 then begin
            if RefundCLE.Get(RefundCLEEntryNo) then
                BankLedgEntry := GetBankLedgEntryByPaymentCLE(RefundCLE);
        end else
            BankLedgEntry := GetBankLedgEntryByTransactionNo(TransactionNo);

        // Settlement Date = the refund's own posting date when resolvable.
        if RefundCLE."Entry No." <> 0 then
            PostingDate := RefundCLE."Posting Date";

        AssignmentID := GenerateAssignmentID(CrMemoCLE."Customer No.", PostingDate);
        CreatePartialCrMemoLineEntries(TempBuffer, CrMemoCLE, PostingDate, BankLedgEntry, AssignmentID, TransactionNo, RefundCLE."Entry No.");
    end;

    local procedure CreatePartialCrMemoLineEntries(
        var TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary;
        CrMemoCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        AssignmentID: Code[50];
        TransactionNo: Integer;
        RefundCLEEntryNo: Integer)
    var
        Customer: Record Customer;
    begin
        Customer.Get(CrMemoCLE."Customer No.");
        if TempBuffer.FindSet() then
            repeat
                InsertPartialCrMemoSettlementEntry(
                    TempBuffer, CrMemoCLE, PostingDate, BankLedgEntry, Customer,
                    AssignmentID, TransactionNo, RefundCLEEntryNo);
            until TempBuffer.Next() = 0;
    end;

    /// <summary>
    /// Creates one Settlement Entry for a CM line from a partial refund allocation.
    /// TempBuffer holds absolute (positive) amounts — CM sign convention (negative) is
    /// restored by negating: LineAmt := -TempBuffer."Alloc. Amt Incl. VAT (LCY)" etc.
    /// No cash discount for partial CM allocations — user allocates refund cash only.
    /// Source Payment CLE Entry No. = RefundCLEEntryNo (consistent with full CM settlements).
    /// </summary>
    local procedure InsertPartialCrMemoSettlementEntry(
        TempBuffer: Record "Pmt. Alloc. Line Buffer";
        CrMemoCLE: Record "Cust. Ledger Entry";
        PostingDate: Date;
        BankLedgEntry: Record "Bank Account Ledger Entry";
        Customer: Record Customer;
        AssignmentID: Code[50];
        TransactionNo: Integer;
        RefundCLEEntryNo: Integer)
    var
        SettlementEntry: Record "Settlement Entry";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        GLAccount: Record "G/L Account";
        LineAmt: Decimal;
        LineAmtInclVAT: Decimal;
    begin
        SettlementEntry.Init();
        SettlementEntry."Transaction Type" := "Settlement Transaction Type"::Sales;
        SettlementEntry."Document Type" := "Gen. Journal Document Type"::"Credit Memo";
        SettlementEntry."Document No." := CrMemoCLE."Document No.";
        SettlementEntry."Document Line No." := TempBuffer."Line No.";

        SettlementEntry."Assignment ID" := AssignmentID;
        SettlementEntry."Settlement Date" := PostingDate;

        // TempBuffer stores absolute (positive) values from the allocation page.
        // SalesCrMemoLine.Amount is positive in BC (the credit granted), so no sign flip needed.
        LineAmtInclVAT := TempBuffer."Alloc. Amt Incl. VAT (LCY)";
        // Back-calculate excl. VAT amount from the line's original VAT ratio.
        if TempBuffer."Orig. Amt Incl. VAT (LCY)" <> 0 then
            LineAmt := Round(LineAmtInclVAT * TempBuffer."Original Amt (LCY)" / TempBuffer."Orig. Amt Incl. VAT (LCY)")
        else
            LineAmt := LineAmtInclVAT;

        // No cash discount for partial CM allocations — user allocates refund cash only.
        // Total Settled Amt = Settlement Amt (no discount component).
        SettlementEntry."Settlement Amt (LCY)" := LineAmt;
        SettlementEntry."Settlement Amt Incl. VAT (LCY)" := LineAmtInclVAT;
        SettlementEntry."Cash Discount Amt (LCY)" := 0;
        SettlementEntry."Cash Discount Amt Incl. VAT (LCY)" := 0;
        SettlementEntry."Total Settled Amt (LCY)" := LineAmt;
        SettlementEntry."Total Settled Amt Incl. VAT (LCY)" := LineAmtInclVAT;

        // TempBuffer stores positive abs values; SalesCrMemoLine.Amount is also positive.
        SettlementEntry."Original Line Amt (LCY)" := TempBuffer."Original Amt (LCY)";
        SettlementEntry."Orig. Line Amt Incl. VAT (LCY)" := TempBuffer."Orig. Amt Incl. VAT (LCY)";

        SettlementEntry."Bank Statement Document No." := BankLedgEntry."Document No.";
        SettlementEntry."CV No." := CrMemoCLE."Customer No.";
        SettlementEntry."CV Name" := Customer.Name;

        SettlementEntry."Global Dimension 1 Code" := TempBuffer."Global Dimension 1 Code";
        SettlementEntry."Global Dimension 2 Code" := TempBuffer."Global Dimension 2 Code";
        SettlementEntry."Dimension Set ID" := TempBuffer."Dimension Set ID";
        PopulateShortcutDimensions(SettlementEntry, TempBuffer."Dimension Set ID");

        SettlementEntry."G/L Account No." := TempBuffer."G/L Account No.";
        if GLAccount.Get(TempBuffer."G/L Account No.") then
            SettlementEntry."G/L Account Name" := GLAccount.Name;

        SettlementEntry.Description := CopyStr(TempBuffer.Description, 1, MaxStrLen(SettlementEntry.Description));

        SettlementEntry."Source Transaction No." := TransactionNo;
        SettlementEntry."Source Payment CLE Entry No." := RefundCLEEntryNo;
        SettlementEntry."Created By" := CopyStr(UserId(), 1, MaxStrLen(SettlementEntry."Created By"));
        SettlementEntry."Created DateTime" := CurrentDateTime();
        SettlementEntry.Insert(true);

        // Update Outstanding Amt and fully-settled flags for the affected credit memo line.
        if SalesCrMemoLine.Get(CrMemoCLE."Document No.", TempBuffer."Line No.") then
            UpdateSalesCrMemoLineOutstandingAmt(SalesCrMemoLine);
    end;

    // ── Private: outstanding amount maintenance ───────────────────────────────

    local procedure UpdateSalesInvLineOutstandingAmt(var SalesInvLine: Record "Sales Invoice Line")
    var
        LatestEntry: Record "Settlement Entry";
    begin
        SalesInvLine.CalcFields("Settled Amt (LCY)");
        SalesInvLine."Outstanding Amt (LCY)" := SalesInvLine.Amount - SalesInvLine."Settled Amt (LCY)";

        // Story 8.1: Maintain Latest Bank Doc. No. — the bank statement document number from
        // the most recent active (non-reversed, non-reversal) settlement entry for this line.
        // Cleared when all settlements for the line have been reversed.
        LatestEntry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        LatestEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        LatestEntry.SetRange("Document No.", SalesInvLine."Document No.");
        LatestEntry.SetRange("Document Line No.", SalesInvLine."Line No.");
        LatestEntry.SetRange("Reversal Entry", false);
        LatestEntry.SetRange(Reversed, false);
        if LatestEntry.FindLast() then
            SalesInvLine."Latest Bank Doc. No." := LatestEntry."Bank Statement Document No."
        else
            SalesInvLine."Latest Bank Doc. No." := '';

        SalesInvLine.Modify();
        UpdateFullySettledFlags(SalesInvLine."Document No.", SalesInvLine."Line No.");
    end;

    local procedure UpdateSalesInvLineOutstandingAmtByLineNo(DocumentNo: Code[20]; LineNo: Integer)
    var
        SalesInvLine: Record "Sales Invoice Line";
    begin
        if not SalesInvLine.Get(DocumentNo, LineNo) then
            exit;
        UpdateSalesInvLineOutstandingAmt(SalesInvLine);
    end;

    /// <summary>
    /// Credit memo mirror of UpdateSalesInvLineOutstandingAmt.
    /// Outstanding Amt (LCY) = Amount - Settled Amt (LCY).
    /// SalesCrMemoLine.Amount is positive (the credit granted to the customer), so Outstanding
    /// starts at Amount and decreases toward 0 as the CM is applied.
    /// Fully settled = Outstanding <= 0 (mirrors the invoice pattern).
    /// </summary>
    local procedure UpdateSalesCrMemoLineOutstandingAmt(var SalesCrMemoLine: Record "Sales Cr.Memo Line")
    begin
        SalesCrMemoLine.CalcFields("Settled Amt (LCY)");
        SalesCrMemoLine."Outstanding Amt (LCY)" := SalesCrMemoLine.Amount - SalesCrMemoLine."Settled Amt (LCY)";
        SalesCrMemoLine.Modify();
        UpdateCrMemoFullySettledFlags(SalesCrMemoLine."Document No.", SalesCrMemoLine."Line No.");
    end;

    local procedure UpdateSalesCrMemoLineOutstandingAmtByLineNo(DocumentNo: Code[20]; LineNo: Integer)
    var
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
    begin
        if not SalesCrMemoLine.Get(DocumentNo, LineNo) then
            exit;
        UpdateSalesCrMemoLineOutstandingAmt(SalesCrMemoLine);
    end;

    /// <summary>
    /// Credit memo mirror of UpdateFullySettledFlags.
    /// Line Fully Settled     = Outstanding Amt (LCY) >= 0 (negative amount has been fully covered).
    /// Document Fully Settled = ALL non-zero lines of the credit memo have Outstanding Amt >= 0.
    /// Both flags are written to every Settlement Entry for the affected line/document.
    /// </summary>
    local procedure UpdateCrMemoFullySettledFlags(DocumentNo: Code[20]; LineNo: Integer)
    var
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        AllLines: Record "Sales Cr.Memo Line";
        SettlementEntry: Record "Settlement Entry";
        LineFullySettled: Boolean;
        DocumentFullySettled: Boolean;
    begin
        // ── Line Fully Settled ───────────────────────────────────────────────
        // SalesCrMemoLine.Amount is positive; Outstanding starts at Amount and falls toward 0.
        // Fully settled = Outstanding <= 0.01 — allow up to 1 cent rounding error from
        // proportional distribution across multiple simultaneous refunds.
        if not SalesCrMemoLine.Get(DocumentNo, LineNo) then
            exit;
        LineFullySettled := SalesCrMemoLine."Outstanding Amt (LCY)" <= 0.01;

        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
        SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        SettlementEntry.SetRange("Document No.", DocumentNo);
        SettlementEntry.SetRange("Document Line No.", LineNo);
        if SettlementEntry.FindSet(true) then
            repeat
                if SettlementEntry."Line Fully Settled" <> LineFullySettled then begin
                    SettlementEntry."Line Fully Settled" := LineFullySettled;
                    SettlementEntry.Modify();
                end;
            until SettlementEntry.Next() = 0;

        // ── Document Fully Settled ───────────────────────────────────────────
        // All non-zero lines must have Outstanding <= 0 (positive Amount fully covered).
        // Use CalcFields("Settled Amt (LCY)") rather than the stored Outstanding Amt field:
        // lines that have never had a settlement entry carry Outstanding Amt = 0 (default),
        // which would falsely pass the check for partial allocations that skip some lines.
        AllLines.SetRange("Document No.", DocumentNo);
        AllLines.SetFilter(Amount, '<>0');
        DocumentFullySettled := true;
        if AllLines.FindSet() then
            repeat
                AllLines.CalcFields("Settled Amt (LCY)");
                // Allow up to 1 cent rounding error from proportional distribution.
                if AllLines.Amount - AllLines."Settled Amt (LCY)" > 0.01 then
                    DocumentFullySettled := false;
            until (AllLines.Next() = 0) or not DocumentFullySettled;

        SettlementEntry.Reset();
        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
        SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        SettlementEntry.SetRange("Document No.", DocumentNo);
        if SettlementEntry.FindSet(true) then
            repeat
                if SettlementEntry."Document Fully Settled" <> DocumentFullySettled then begin
                    SettlementEntry."Document Fully Settled" := DocumentFullySettled;
                    SettlementEntry.Modify();
                end;
            until SettlementEntry.Next() = 0;
    end;

    /// <summary>
    /// Updates "Line Fully Settled" and "Document Fully Settled" on ALL Settlement Entries
    /// for the affected line and document after every insert or reversal.
    ///
    /// Line Fully Settled  = Outstanding Amt (LCY) <= 0 for this specific line.
    /// Document Fully Settled = ALL lines of the invoice have Outstanding Amt (LCY) <= 0.
    ///
    /// Both flags are stored on every Settlement Entry (not just the latest) so Power BI
    /// and the API can filter on current settlement state without joins or recalculation.
    /// Reversals in Epic 5 must also call UpdateSalesInvLineOutstandingAmt to trigger this.
    /// </summary>
    local procedure UpdateFullySettledFlags(DocumentNo: Code[20]; LineNo: Integer)
    var
        SalesInvLine: Record "Sales Invoice Line";
        AllLines: Record "Sales Invoice Line";
        SettlementEntry: Record "Settlement Entry";
        LineFullySettled: Boolean;
        DocumentFullySettled: Boolean;
    begin
        // ── Line Fully Settled ───────────────────────────────────────────────
        // Allow up to 1 cent rounding error from proportional distribution across
        // multiple simultaneous payments (mirrors the CM path tolerance).
        if not SalesInvLine.Get(DocumentNo, LineNo) then
            exit;
        LineFullySettled := SalesInvLine."Outstanding Amt (LCY)" <= 0.01;

        // Update all entries for this line
        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        SettlementEntry.SetRange("Document No.", DocumentNo);
        SettlementEntry.SetRange("Document Line No.", LineNo);
        if SettlementEntry.FindSet(true) then
            repeat
                if SettlementEntry."Line Fully Settled" <> LineFullySettled then begin
                    SettlementEntry."Line Fully Settled" := LineFullySettled;
                    SettlementEntry.Modify();
                end;
            until SettlementEntry.Next() = 0;

        // ── Document Fully Settled ────────────────────────────────────────────
        // Check all non-zero lines of the invoice — invoice is fully settled only
        // when every line has Outstanding Amt <= 0.
        // Allow up to 1 cent rounding error from proportional distribution across
        // multiple simultaneous payments (mirrors the CM path tolerance).
        AllLines.SetRange("Document No.", DocumentNo);
        AllLines.SetFilter(Amount, '<>0');
        DocumentFullySettled := true;
        if AllLines.FindSet() then
            repeat
                if AllLines."Outstanding Amt (LCY)" > 0.01 then
                    DocumentFullySettled := false;
            until (AllLines.Next() = 0) or not DocumentFullySettled;

        // Update all entries for the whole document
        SettlementEntry.Reset();
        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        SettlementEntry.SetRange("Document No.", DocumentNo);
        if SettlementEntry.FindSet(true) then
            repeat
                if SettlementEntry."Document Fully Settled" <> DocumentFullySettled then begin
                    SettlementEntry."Document Fully Settled" := DocumentFullySettled;
                    SettlementEntry.Modify();
                end;
            until SettlementEntry.Next() = 0;
    end;
}
