namespace P3.TXL.Payment.Settlement;

using Microsoft.Bank.Ledger;
using Microsoft.Foundation.Navigate;

codeunit 51112 "Settlement Navigate Handler"
{
    [EventSubscriber(ObjectType::Page, Page::Navigate, 'OnAfterNavigateFindRecords', '', false, false)]
    local procedure OnAfterNavigateFindRecords(var DocumentEntry: Record "Document Entry"; DocNoFilter: Text; PostingDateFilter: Text; NewSourceRecVar: Variant; ExtDocNo: Code[250]; HideDialog: Boolean)
    var
        SettlementEntry: Record "Settlement Entry";
        RecRef: RecordRef;
        BankLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        if DocNoFilter = '' then exit;

        if NewSourceRecVar.IsRecord() then begin
            RecRef.GetTable(NewSourceRecVar);
            if RecRef.Number = Database::"Bank Account Ledger Entry" then begin
                RecRef.SetTable(BankLedgerEntry);
                SettlementEntry.SetRange("Bank Statement Document No.", BankLedgerEntry."Document No.");
                DocumentEntry.InsertIntoDocEntry(Database::"Settlement Entry", SettlementEntry.TableCaption(), SettlementEntry.Count());
                exit;
            end;
        end;

        SettlementEntry.SetFilter("Document No.", DocNoFilter);
        DocumentEntry.InsertIntoDocEntry(Database::"Settlement Entry", SettlementEntry.TableCaption(), SettlementEntry.Count());
    end;

    [EventSubscriber(ObjectType::Page, Page::Navigate, 'OnBeforeShowRecords', '', false, false)]
    local procedure OnBeforeShowRecords(var TempDocumentEntry: Record "Document Entry"; DocNoFilter: Text; PostingDateFilter: Text; var IsHandled: Boolean; ContactNo: Code[250])
    var
        SettlementEntry: Record "Settlement Entry";
    begin
        if TempDocumentEntry."Table ID" <> Database::"Settlement Entry" then exit;
        IsHandled := true;

        SettlementEntry.SetFilter("Document No.", DocNoFilter);
        if SettlementEntry.IsEmpty() then begin
            SettlementEntry.Reset();
            SettlementEntry.SetFilter("Bank Statement Document No.", DocNoFilter);
        end;
        Page.Run(0, SettlementEntry);
    end;
}
