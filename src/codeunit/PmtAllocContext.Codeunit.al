namespace P3.TXL.Payment.Settlement;

using Microsoft.Sales.Receivables;

/// <summary>
/// SingleInstance bridge between the pre-posting event (where RunModal is allowed) and the
/// post-commit event (where Settlement Entries are written in a fresh transaction).
///
/// Flow for partial payments:
///   1. OnBeforeCode / OnBeforeApply fires before any write transaction.
///      SetDCLEBaseline records the current max DCLE Entry No.
///      PreparePartialPaymentAllocation opens the allocation page, collects the user's
///      line distribution, and calls StoreAllocation.
///   2. BC posts and commits the application (G/L entries, CLEs, DCLEs).
///   3. OnAfterCode / OnBeforeRunUpdateAnalysisView fires after Commit().
///      GetDCLEBaseline retrieves the snapshot, ProcessNewApplicationDCLEs finds all new
///      Application DCLEs and creates Settlement Entries. ClearDCLEBaseline resets the flag.
///
/// Multi-slot design: PendingBuffer holds allocations for ALL invoices currently in flight,
/// keyed by "Inv. CLE Entry No." (composite PK with "Line No."). This supports batches
/// with multiple partial payments and single payments applied to multiple invoices at once.
/// Uniprocess posting is sequential so concurrent access is not a concern.
/// </summary>
codeunit 51107 "Pmt. Alloc. Context"
{
    SingleInstance = true;

    var
        PendingBuffer: Record "Pmt. Alloc. Line Buffer" temporary;
        DCLEBaseline: Integer;
        DCLEBaselineIsSet: Boolean;
        PaymentCLEByInvoice: Dictionary of [Integer, Integer]; // InvCLEEntryNo → PaymentCLEEntryNo

    /// <summary>
    /// Returns true if an allocation has already been collected for the given invoice CLE entry.
    /// Prevents double-prompting when both invoice-side and payment-side DCLEs fire.
    /// </summary>
    procedure IsHandled(InvCLEEntryNo: Integer): Boolean
    begin
        PendingBuffer.SetRange("Inv. CLE Entry No.", InvCLEEntryNo);
        exit(not PendingBuffer.IsEmpty());
    end;

    /// <summary>
    /// Stores the user's allocation lines keyed by invoice CLE entry no.
    /// Called by PreparePartialPaymentAllocation after the user confirms.
    /// Any existing allocation for this invoice is replaced.
    /// </summary>
    procedure StoreAllocation(InvCLEEntryNo: Integer; var TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary)
    begin
        PendingBuffer.SetRange("Inv. CLE Entry No.", InvCLEEntryNo);
        PendingBuffer.DeleteAll();
        PendingBuffer.Reset();
        if TempBuffer.FindSet() then
            repeat
                PendingBuffer := TempBuffer;
                PendingBuffer."Inv. CLE Entry No." := InvCLEEntryNo;
                PendingBuffer.Insert();
            until TempBuffer.Next() = 0;
        PendingBuffer.Reset();
    end;

    /// <summary>
    /// Copies the stored allocation lines for InvCLEEntryNo into TempBuffer.
    /// Returns false if no allocation is stored for that invoice.
    /// </summary>
    procedure TryGetAllocation(InvCLEEntryNo: Integer; var TempBuffer: Record "Pmt. Alloc. Line Buffer" temporary): Boolean
    begin
        PendingBuffer.Reset();
        PendingBuffer.SetRange("Inv. CLE Entry No.", InvCLEEntryNo);
        if PendingBuffer.IsEmpty() then
            exit(false);
        TempBuffer.Reset();
        TempBuffer.DeleteAll();
        if PendingBuffer.FindSet() then
            repeat
                TempBuffer := PendingBuffer;
                TempBuffer.Insert();
            until PendingBuffer.Next() = 0;
        PendingBuffer.Reset();
        exit(true);
    end;

    /// <summary>
    /// Clears the stored allocation for InvCLEEntryNo after it has been consumed.
    /// Other invoices' allocations in the buffer are not affected.
    /// </summary>
    procedure ClearAllocation(InvCLEEntryNo: Integer)
    begin
        PendingBuffer.SetRange("Inv. CLE Entry No.", InvCLEEntryNo);
        PendingBuffer.DeleteAll();
        PendingBuffer.Reset();
    end;

    // ── Payment CLE lookup: apply-from-invoice path ─────────────────────────
    // For the apply-from-invoice CLE path, BC does not set "Applied Cust. Ledger Entry No."
    // on the invoice DCLE to the payment CLE entry no (it is 0 or a self-reference).
    // The payment CLE entry no is therefore stored here at pre-scan time (before posting),
    // when "Amount to Apply" is still set on the payment CLEs.

    /// <summary>
    /// Stores the applying payment CLE entry no. for the given invoice CLE.
    /// Call this from ScanForCLEPartialPayments (apply-from-invoice direction) after the
    /// allocation popup has been shown, before the write transaction starts.
    /// </summary>
    procedure StorePaymentCLE(InvCLEEntryNo: Integer; PaymentCLEEntryNo: Integer)
    begin
        if PaymentCLEEntryNo = 0 then
            exit;
        if PaymentCLEByInvoice.ContainsKey(InvCLEEntryNo) then
            PaymentCLEByInvoice.Set(InvCLEEntryNo, PaymentCLEEntryNo)
        else
            PaymentCLEByInvoice.Add(InvCLEEntryNo, PaymentCLEEntryNo);
    end;

    /// <summary>
    /// Returns the stored applying payment CLE entry no. for the given invoice CLE.
    /// Returns 0 if none was stored (i.e., not the apply-from-invoice path).
    /// </summary>
    procedure GetPaymentCLE(InvCLEEntryNo: Integer): Integer
    var
        EntryNo: Integer;
    begin
        if PaymentCLEByInvoice.Get(InvCLEEntryNo, EntryNo) then
            exit(EntryNo);
        exit(0);
    end;

    /// <summary>
    /// Clears the stored payment CLE entry no. for the given invoice CLE after it has been consumed.
    /// </summary>
    procedure ClearPaymentCLE(InvCLEEntryNo: Integer)
    begin
        if PaymentCLEByInvoice.ContainsKey(InvCLEEntryNo) then
            PaymentCLEByInvoice.Remove(InvCLEEntryNo);
    end;

    // ── DCLE baseline: post-commit redesign ─────────────────────────────────
    // Stores the max Detailed Cust. Ledg. Entry No. immediately BEFORE a posting
    // transaction begins. After the commit, ProcessNewApplicationDCLEs uses this
    // value to find only the DCLEs created by that posting.

    /// <summary>
    /// Records the current highest Detailed Cust. Ledg. Entry No. as the baseline.
    /// Call this before the posting transaction starts (in a pre-posting event).
    /// </summary>
    procedure SetDCLEBaseline()
    var
        DCLE: Record "Detailed Cust. Ledg. Entry";
    begin
        DCLEBaseline := 0;
        if DCLE.FindLast() then
            DCLEBaseline := DCLE."Entry No.";
        DCLEBaselineIsSet := true;
    end;

    /// <summary>
    /// Returns the stored DCLE baseline entry no. in EntryNo.
    /// Returns false if no baseline has been set (i.e., SetDCLEBaseline was not called).
    /// </summary>
    procedure GetDCLEBaseline(var EntryNo: Integer): Boolean
    begin
        if not DCLEBaselineIsSet then
            exit(false);
        EntryNo := DCLEBaseline;
        exit(true);
    end;

    /// <summary>
    /// Clears the stored DCLE baseline after it has been consumed by ProcessNewApplicationDCLEs.
    /// </summary>
    procedure ClearDCLEBaseline()
    begin
        DCLEBaseline := 0;
        DCLEBaselineIsSet := false;
    end;
}
