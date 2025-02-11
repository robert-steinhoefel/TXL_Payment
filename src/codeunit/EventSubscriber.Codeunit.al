namespace P3.TXL.Payment.System;
using P3.TXL.Payment.Vendor;
using P3.TXL.Payment.Customer;
using Microsoft.Finance.GeneralLedger.Posting;
using Microsoft.Bank.BankAccount;
using Microsoft.Finance.GeneralLedger.Ledger;
using P3.TXL.Payment.BankAccount;
using Microsoft.Purchases.Payables;
using Microsoft.Sales.Receivables;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.ReceivablesPayables;

codeunit 51100 "Event Subscriber"
{
    [EventSubscriber(ObjectType::Table, Database::"Detailed Vendor Ledg. Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDetailedVendorLedgerEntry(var Rec: Record "Detailed Vendor Ledg. Entry"; RunTrigger: Boolean)
    var
    begin
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
        if Rec."Entry Type" <> Microsoft.Finance.ReceivablesPayables."Detailed CV Ledger Entry Type"::Application then
            exit;
        if Rec."Initial Document Type" = "Gen. Journal Document Type"::Payment then
            exit;
        if Rec."Initial Document Type" = "Gen. Journal Document Type"::Refund then
            exit;
        Codeunit.Run(Codeunit::"Customer Ledger Entries", Rec);
    end;

    // Possible other entry points:

    // [EventSubscriber(ObjectType::Table, Database::"Bank Account Ledger Entry", 'OnAfterCopyFromGenJnlLine', '', false, false)]
    //     // #1

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnAfterPostBankAcc', '', false, false)]
    //     // #3

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnPostBankAccOnAfterBankAccLedgEntryInsert', '', false, false)]
    //     // #2
    //     // Fired before Detailed Ledger Entry is being created. --> Too early

}
