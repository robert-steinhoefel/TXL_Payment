namespace P3.TXL.Payment.System;

using P3.TXL.Payment.Vendor;
using P3.TXL.Payment.BankAccount;
using P3.TXL.Payment.Settlement;
using Microsoft.Purchases.Payables;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.Receivables;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Finance.GeneralLedger.Posting;

codeunit 51100 "Event Subscriber"
{
    [EventSubscriber(ObjectType::Table, Database::"Detailed Vendor Ledg. Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDetailedVendorLedgerEntry(var Rec: Record "Detailed Vendor Ledg. Entry"; RunTrigger: Boolean)
    var
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Entry Type" <> "Detailed CV Ledger Entry Type"::Application then
            exit;
        if Rec."Initial Document Type" = "Gen. Journal Document Type"::Payment then
            exit;
        if Rec."Initial Document Type" = "Gen. Journal Document Type"::Refund then
            exit;
        Codeunit.Run(Codeunit::"Vendor Ledger Entries", Rec);
    end;

    /// <summary>
    /// Fires at the very start of Gen. Jnl.-Post Batch.Code(), before LockTable, before any
    /// write transaction, and before Commit — full UI context, RunModal is allowed.
    /// Snapshots the current max DCLE Entry No. as baseline, then scans all journal lines
    /// in the batch for partial applications and opens the allocation page for each one,
    /// storing the user's distribution in Pmt. Alloc. Context.
    /// OnAfterCodeGenJnlPostBatch consumes the stored allocations after the commit.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Batch", 'OnBeforeCode', '', false, false)]
    local procedure OnBeforeCodeGenJnlPostBatch(
        var GenJournalLine: Record "Gen. Journal Line"; PreviewMode: Boolean; CommitIsSuppressed: Boolean)
    var
        SettlementEntryMgt: Codeunit "Settlement Entry Mgt.";
        AllocContext: Codeunit "Pmt. Alloc. Context";
    begin
        // RunModal is not allowed during posting preview — BC holds the session in a
        // consistent-table state that forbids UI dialogs. Skip entirely;
        // no allocation entries are created during preview anyway.
        if PreviewMode then
            exit;
        AllocContext.SetDCLEBaseline();
        SettlementEntryMgt.ScanBatchForPartialPayments(GenJournalLine);
    end;

    /// <summary>
    /// Fires after Gen. Jnl.-Post Batch.Code() has committed the entire batch.
    /// Reads the DCLE baseline stored by OnBeforeCodeGenJnlPostBatch, finds all
    /// Application DCLEs created since that baseline, and creates Settlement Entries.
    /// Runs in a fresh transaction — immune to any interference during the write transaction.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Batch", 'OnAfterCode', '', false, false)]
    local procedure OnAfterCodeGenJnlPostBatch(var GenJournalLine: Record "Gen. Journal Line"; PreviewMode: Boolean)
    var
        SettlementEntryMgt: Codeunit "Settlement Entry Mgt.";
        AllocContext: Codeunit "Pmt. Alloc. Context";
        BaselineDCLEEntryNo: Integer;
    begin
        if PreviewMode then
            exit;
        if not AllocContext.GetDCLEBaseline(BaselineDCLEEntryNo) then
            exit;
        AllocContext.ClearDCLEBaseline();
        SettlementEntryMgt.ProcessNewApplicationDCLEs(BaselineDCLEEntryNo);
    end;

    /// <summary>
    /// Fires at the very start of CustEntry-Apply Posted Entries.Apply() (codeunit 226),
    /// BEFORE any LockTable call — RunModal is allowed here.
    /// Snapshots the current max DCLE Entry No. as baseline, then scans for partial
    /// applications and opens the allocation page for each one.
    /// OnBeforeRunUpdateAnalysisViewCustEntryApply consumes the stored allocations
    /// after the commit (OnBeforeRunUpdateAnalysisView fires after Commit() in CustPostApplyCustLedgEntry).
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CustEntry-Apply Posted Entries", 'OnBeforeApply', '', false, false)]
    local procedure OnBeforeApplyCustEntryApplyPostedEntries(
        var CustLedgerEntry: Record "Cust. Ledger Entry";
        var DocumentNo: Code[20];
        var ApplicationDate: Date)
    var
        SettlementEntryMgt: Codeunit "Settlement Entry Mgt.";
        AllocContext: Codeunit "Pmt. Alloc. Context";
    begin
        AllocContext.SetDCLEBaseline();
        SettlementEntryMgt.ScanCLEApplicationForPartialPayments(CustLedgerEntry, ApplicationDate);
    end;

    /// <summary>
    /// Fires inside CustEntry-Apply Posted Entries.CustPostApplyCustLedgEntry() AFTER Commit().
    /// Reads the DCLE baseline stored by OnBeforeApplyCustEntryApplyPostedEntries, finds all
    /// Application DCLEs created since that baseline, and creates Settlement Entries.
    /// IsHandled is intentionally NOT set to true — the analysis view update must still run.
    /// </summary>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CustEntry-Apply Posted Entries", 'OnBeforeRunUpdateAnalysisView', '', false, false)]
    local procedure OnBeforeRunUpdateAnalysisViewCustEntryApply(var IsHandled: Boolean)
    var
        SettlementEntryMgt: Codeunit "Settlement Entry Mgt.";
        AllocContext: Codeunit "Pmt. Alloc. Context";
        BaselineDCLEEntryNo: Integer;
    begin
        if not AllocContext.GetDCLEBaseline(BaselineDCLEEntryNo) then
            exit;
        AllocContext.ClearDCLEBaseline();
        SettlementEntryMgt.ProcessNewApplicationDCLEs(BaselineDCLEEntryNo);
    end;

    [EventSubscriber(ObjectType::Table, Database::"G/L Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertGLEntry(var Rec: Record "G/L Entry")
    var
        BankAccountLedgerEntry: Record "Bank Account Ledger Entry";
        SetBankLedgerEntry: Codeunit "Bank Account Ledger Entries";
        LedgerEntry: Variant;
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."Bal. Account Type" <> "Gen. Journal Account Type"::"Bank Account" then
            exit;
        LedgerEntry := Rec;
        BankAccountLedgerEntry.SetRange("Transaction No.", Rec."Transaction No.");
        if BankAccountLedgerEntry.FindFirst() then
            SetBankLedgerEntry.GetAndProcessLedgerEntries(BankAccountLedgerEntry, LedgerEntry);
    end;
}
