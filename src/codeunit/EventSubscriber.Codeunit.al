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

    // [EventSubscriber(ObjectType::Table, Database::"Bank Account Ledger Entry", 'OnAfterInsertEvent', '', false, false)]
    // local procedure OnAfterInsertBankAccountLedgerEntry(var Rec: Record "Bank Account Ledger Entry"; RunTrigger: Boolean)
    // var
    // begin
    //     Codeunit.Run(Codeunit::"Bank Account Ledger Entries", Rec);
    // end;

    // [EventSubscriber(ObjectType::Table, Database::"Bank Account Ledger Entry", 'OnAfterCopyFromGenJnlLine', '', false, false)]
    // local procedure OnAfterCopyFromGenJnlLine(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry")
    // var
    // begin
    //     // #1
    //     // Codeunit.Run(Codeunit::"Bank Account Ledger Entries", BankAccountLedgerEntry);
    //     Message('Halt.');
    // end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Batch", 'OnAfterPostReversingLines', '', false, false)]
    // local procedure OnAfterPostReversingLines(var GenJournalLine: Record "Gen. Journal Line"; PreviewMode: Boolean)
    // var
    // begin
    //     // Codeunit.Run(Codeunit::"Bank Account Ledger Entries", BankAccountLedgerEntry);
    //     Message('Halt.');
    // end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnAfterPostBankAcc', '', false, false)]
    // local procedure OnAfterPostBankAcc(var GenJnlLine: Record "Gen. Journal Line"; Balancing: Boolean; var TempGLEntryBuf: Record "G/L Entry" temporary; var NextEntryNo: Integer; var NextTransactionNo: Integer)
    // var
    // begin
    //     // #3
    //     // Codeunit.Run(Codeunit::"Bank Account Ledger Entries", BankAccountLedgerEntry);
    //     Message('Halt.');
    // end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnPostBankAccOnAfterBankAccLedgEntryInsert', '', false, false)]
    // local procedure OnPostBankAccOnAfterBankAccLedgEntryInsert(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry"; var GenJournalLine: Record "Gen. Journal Line"; BankAccount: Record "Bank Account")
    // var
    // begin
    //     // #2
    //     // Fired before Detailed Ledger Entry is being created. --> Too early
    //     Message('Halt.');
    //     // Codeunit.Run(Codeunit::"Bank Account Ledger Entries", BankAccountLedgerEntry);
    // end;

}
