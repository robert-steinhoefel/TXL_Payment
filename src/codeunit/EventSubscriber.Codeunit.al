namespace P3.TXL.Payment.System;

using P3.TXL.Payment.Vendor;
using P3.TXL.Payment.Customer;
using P3.TXL.Payment.BankAccount;
using Microsoft.Purchases.Payables;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Sales.Receivables;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.ReceivablesPayables;

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

    [EventSubscriber(ObjectType::Table, Database::"Detailed Cust. Ledg. Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDetailedCustomerLedgerEntry(var Rec: Record "Detailed Cust. Ledg. Entry"; RunTrigger: Boolean)
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
        Codeunit.Run(Codeunit::"Customer Ledger Entries", Rec);
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
