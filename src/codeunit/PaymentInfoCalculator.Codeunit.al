namespace P3.TXL.Payment.Settlement;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Purchases.History;
using Microsoft.Sales.History;

// Story 8.1: Derives payment status from settlement data on invoice/credit memo lines and headers.
// Kept as a standalone codeunit so the logic is reusable across all page extensions without duplication.
//
// All status methods use the same two-step pattern:
//   1. CalcSums("Total Settled Amt (LCY)") across ALL entries including reversals (which carry
//      negative amounts). Net <= 0.01 means nothing is effectively settled → Open.
//      This handles reversal correctly regardless of whether "Reversed" is set on the original.
//   2. Check if the outstanding amount (Amount minus net settled) is within the 0.01 rounding
//      tolerance. If so → Paid. Otherwise → Partial.
//
// This approach never reads the stored "Line Fully Settled" / "Document Fully Settled" flags on
// Settlement Entries, because those flags can be stale if they were written by older code with
// a different tolerance threshold. The document-level check reads "Outstanding Amt (LCY)" from
// the actual posted line records, which is always kept up to date by SettlementEntryMgt.
codeunit 51111 "Payment Info Calculator"
{
    // ── Line-level: Sales Invoice Line ───────────────────────────────────────

    procedure GetPaymentStatus(SalesInvLine: Record "Sales Invoice Line"): Enum "Settlement Payment Status"
    var
        Entry: Record "Settlement Entry";
        NetSettled: Decimal;
    begin
        Entry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        Entry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        Entry.SetRange("Document No.", SalesInvLine."Document No.");
        Entry.SetRange("Document Line No.", SalesInvLine."Line No.");
        Entry.CalcSums("Total Settled Amt (LCY)");
        NetSettled := Entry."Total Settled Amt (LCY)";
        if NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Open);
        if SalesInvLine.Amount - NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Paid);
        exit("Settlement Payment Status"::Partial);
    end;

    // ── Line-level: Purch. Inv. Line ─────────────────────────────────────────

    procedure GetPaymentStatus(PurchInvLine: Record "Purch. Inv. Line"): Enum "Settlement Payment Status"
    var
        Entry: Record "Settlement Entry";
        NetSettled: Decimal;
    begin
        Entry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
        Entry.SetRange("Transaction Type", "Settlement Transaction Type"::Purchase);
        Entry.SetRange("Document No.", PurchInvLine."Document No.");
        Entry.SetRange("Document Line No.", PurchInvLine."Line No.");
        Entry.CalcSums("Total Settled Amt (LCY)");
        NetSettled := Entry."Total Settled Amt (LCY)";
        if NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Open);
        if PurchInvLine.Amount - NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Paid);
        exit("Settlement Payment Status"::Partial);
    end;

    // ── Line-level: Sales Cr.Memo Line ───────────────────────────────────────
    // SalesCrMemoLine.Amount is positive (credit granted to the customer).
    // Outstanding starts at Amount and falls toward 0 as the CM is applied.

    procedure GetPaymentStatus(SalesCrMemoLine: Record "Sales Cr.Memo Line"): Enum "Settlement Payment Status"
    var
        Entry: Record "Settlement Entry";
        NetSettled: Decimal;
    begin
        Entry.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
        Entry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
        Entry.SetRange("Document No.", SalesCrMemoLine."Document No.");
        Entry.SetRange("Document Line No.", SalesCrMemoLine."Line No.");
        Entry.CalcSums("Total Settled Amt (LCY)");
        NetSettled := Entry."Total Settled Amt (LCY)";
        if NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Open);
        if SalesCrMemoLine.Amount - NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Paid);
        exit("Settlement Payment Status"::Partial);
    end;

    // ── Line-level: Purch. Cr. Memo Line ─────────────────────────────────────
    // Will show Open until Epic 9 adds purchase credit memo settlement creation.

    procedure GetPaymentStatus(PurchCrMemoLine: Record "Purch. Cr. Memo Line"): Enum "Settlement Payment Status"
    var
        Entry: Record "Settlement Entry";
        NetSettled: Decimal;
    begin
        Entry.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
        Entry.SetRange("Transaction Type", "Settlement Transaction Type"::Purchase);
        Entry.SetRange("Document No.", PurchCrMemoLine."Document No.");
        Entry.SetRange("Document Line No.", PurchCrMemoLine."Line No.");
        Entry.CalcSums("Total Settled Amt (LCY)");
        NetSettled := Entry."Total Settled Amt (LCY)";
        if NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Open);
        if PurchCrMemoLine.Amount - NetSettled <= 0.01 then
            exit("Settlement Payment Status"::Paid);
        exit("Settlement Payment Status"::Partial);
    end;

    // ── Document-level ────────────────────────────────────────────────────────

    /// <summary>
    /// Returns the payment status for an entire document.
    /// Step 1: net CalcSums across all entries (reversals cancel positives) — net at or below
    ///         0.01 means nothing is effectively settled → Open.
    /// Step 2: read "Outstanding Amt (LCY)" from the actual posted line records (maintained by
    ///         SettlementEntryMgt) to distinguish Paid from Partial. This avoids the stale
    ///         "Document Fully Settled" flag on Settlement Entries.
    /// </summary>
    procedure GetDocumentPaymentStatus(DocumentNo: Code[20]; DocumentType: Enum "Gen. Journal Document Type"; TransactionType: Enum "Settlement Transaction Type"): Enum "Settlement Payment Status"
    var
        Entry: Record "Settlement Entry";
    begin
        Entry.SetRange("Document Type", DocumentType);
        Entry.SetRange("Transaction Type", TransactionType);
        Entry.SetRange("Document No.", DocumentNo);
        Entry.CalcSums("Total Settled Amt (LCY)");
        if Entry."Total Settled Amt (LCY)" <= 0.01 then
            exit("Settlement Payment Status"::Open);
        if IsDocumentFullySettled(DocumentNo, DocumentType, TransactionType) then
            exit("Settlement Payment Status"::Paid);
        exit("Settlement Payment Status"::Partial);
    end;

    /// <summary>
    /// Returns the net total settled amount (excl. VAT) across all lines of the document.
    /// Includes reversal entries (negative amounts), so the result is always the net figure.
    /// </summary>
    procedure GetDocumentTotalSettled(DocumentNo: Code[20]; DocumentType: Enum "Gen. Journal Document Type"; TransactionType: Enum "Settlement Transaction Type"): Decimal
    var
        Entry: Record "Settlement Entry";
    begin
        Entry.SetRange("Document Type", DocumentType);
        Entry.SetRange("Transaction Type", TransactionType);
        Entry.SetRange("Document No.", DocumentNo);
        Entry.CalcSums("Total Settled Amt (LCY)");
        exit(Entry."Total Settled Amt (LCY)");
    end;

    /// <summary>
    /// Returns the most recent non-reversal settlement date across all lines of the document.
    /// </summary>
    procedure GetDocumentLatestSettlementDate(DocumentNo: Code[20]; DocumentType: Enum "Gen. Journal Document Type"; TransactionType: Enum "Settlement Transaction Type"): Date
    var
        Entry: Record "Settlement Entry";
    begin
        Entry.SetRange("Document Type", DocumentType);
        Entry.SetRange("Transaction Type", TransactionType);
        Entry.SetRange("Document No.", DocumentNo);
        Entry.SetRange("Reversal Entry", false);
        if Entry.FindLast() then
            exit(Entry."Settlement Date");
        exit(0D);
    end;

    // ── Shared style helper ───────────────────────────────────────────────────

    procedure GetPaymentStatusStyle(Status: Enum "Settlement Payment Status"): Text
    begin
        case Status of
            "Settlement Payment Status"::Paid:
                exit('Favorable');
            "Settlement Payment Status"::Partial:
                exit('Ambiguous');
            else
                exit('');
        end;
    end;

    // ── Private ───────────────────────────────────────────────────────────────

    /// <summary>
    /// Returns true if all non-zero lines of the document have Outstanding Amt within the
    /// 0.01 rounding tolerance. Reads "Outstanding Amt (LCY)" from the actual posted line
    /// records — maintained by SettlementEntryMgt after every insert/reversal and always
    /// current, unlike the "Document Fully Settled" flag on Settlement Entries.
    /// </summary>
    local procedure IsDocumentFullySettled(DocumentNo: Code[20]; DocumentType: Enum "Gen. Journal Document Type"; TransactionType: Enum "Settlement Transaction Type"): Boolean
    var
        SalesInvLine: Record "Sales Invoice Line";
        SalesCrMemoLine: Record "Sales Cr.Memo Line";
        PurchInvLine: Record "Purch. Inv. Line";
        PurchCrMemoLine: Record "Purch. Cr. Memo Line";
    begin
        case true of
            (DocumentType = "Gen. Journal Document Type"::Invoice) and
            (TransactionType = "Settlement Transaction Type"::Sales):
                begin
                    SalesInvLine.SetRange("Document No.", DocumentNo);
                    SalesInvLine.SetFilter(Amount, '<>0');
                    if SalesInvLine.FindSet() then
                        repeat
                            if SalesInvLine."Outstanding Amt (LCY)" > 0.01 then
                                exit(false);
                        until SalesInvLine.Next() = 0;
                    exit(true);
                end;
            (DocumentType = "Gen. Journal Document Type"::"Credit Memo") and
            (TransactionType = "Settlement Transaction Type"::Sales):
                begin
                    SalesCrMemoLine.SetRange("Document No.", DocumentNo);
                    SalesCrMemoLine.SetFilter(Amount, '<>0');
                    if SalesCrMemoLine.FindSet() then
                        repeat
                            if SalesCrMemoLine."Outstanding Amt (LCY)" > 0.01 then
                                exit(false);
                        until SalesCrMemoLine.Next() = 0;
                    exit(true);
                end;
            (DocumentType = "Gen. Journal Document Type"::Invoice) and
            (TransactionType = "Settlement Transaction Type"::Purchase):
                begin
                    PurchInvLine.SetRange("Document No.", DocumentNo);
                    PurchInvLine.SetFilter(Amount, '<>0');
                    if PurchInvLine.FindSet() then
                        repeat
                            if PurchInvLine."Outstanding Amt (LCY)" > 0.01 then
                                exit(false);
                        until PurchInvLine.Next() = 0;
                    exit(true);
                end;
            (DocumentType = "Gen. Journal Document Type"::"Credit Memo") and
            (TransactionType = "Settlement Transaction Type"::Purchase):
                begin
                    PurchCrMemoLine.SetRange("Document No.", DocumentNo);
                    PurchCrMemoLine.SetFilter(Amount, '<>0');
                    if PurchCrMemoLine.FindSet() then
                        repeat
                            if PurchCrMemoLine."Outstanding Amt (LCY)" > 0.01 then
                                exit(false);
                        until PurchCrMemoLine.Next() = 0;
                    exit(true);
                end;
        end;
        exit(false);
    end;
}
