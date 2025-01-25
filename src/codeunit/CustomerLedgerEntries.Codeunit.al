namespace ALExtensions.ALExtensions;

using Microsoft.Sales.Receivables;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;

codeunit 51103 "Customer Ledger Entries"
{
    TableNo = "Detailed Cust. Ledg. Entry";
    Permissions = tabledata "G/L Entry" = rm,
                    tabledata "Cust. Ledger Entry" = rm;

    trigger OnRun()
    begin
        if not (Rec."Entry Type" = "Detailed CV Ledger Entry Type"::Application) then
            exit;
        if not ((Rec."Initial Document Type" = "Gen. Journal Document Type"::Invoice) or (Rec."Initial Document Type" = "Gen. Journal Document Type"::"Credit Memo")) then
            exit;
        // if ((Rec."Document Type" = "Gen. Journal Document Type"::Invoice) or (Rec."Initial Document Type" = "Gen. Journal Document Type"::"Credit Memo")) then
        //     exit;
        ProcessLedgerEntries(Rec);
    end;

    local procedure ProcessLedgerEntries(var Rec: Record "Detailed Cust. Ledg. Entry")
    var
        DetailedCustLedgerEntry, PmtDLEHelperEntry : Record "Detailed Cust. Ledg. Entry";
        InvoiceLedgerEntry, PaymentLedgerEntry, PmtLEHelperEntry : Record "Cust. Ledger Entry";
        BankLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        PaymentLedgerEntry.Get(Rec."Applied Cust. Ledger Entry No.");
        BankLedgerEntry := GetBankLedgerEntry(PaymentLedgerEntry);
        if (BankLedgerEntry."Entry No." = 0) then begin
            if not Rec.Unapplied = true then begin
                // If payment is has not been posted through bank account, we'll use the vendor's payment ledger entry data.
                // If posting is an un-application, these fields will remain empty - on purpose.
                BankLedgerEntry."Posting Date" := PaymentLedgerEntry."Posting Date";
                BankLedgerEntry."Document No." := PaymentLedgerEntry."Document No.";
            end;
        end;
        InvoiceLedgerEntry.Get(Rec."Cust. Ledger Entry No.");
        GetAndSetGLEntriesPaid(BankLedgerEntry, InvoiceLedgerEntry);
    end;

    local procedure GetAndSetGLEntriesPaid(var BankLedgerEntry: Record "Bank Account Ledger Entry"; var CustomerLedgerEntry: Record "Cust. Ledger Entry")
    var
        GLEntries: Record "G/L Entry";
    begin
        // ISSUE: What about partial payments to ledger entries?
        // ISSUE: When an invoice is being applied to two payments and one of those payments is cancelled, the entry is not modified.
        if not (BankLedgerEntry."Posting Date" = 0D) then begin
            CustomerLedgerEntry.Paid := true;
            CustomerLedgerEntry."Pmt Cancelled" := false;
        end else begin
            CustomerLedgerEntry.Paid := false;
            CustomerLedgerEntry."Pmt Cancelled" := true;
        end;
        CustomerLedgerEntry."Bank Posting Date" := BankLedgerEntry."Posting Date";
        CustomerLedgerEntry."Bank Document No." := BankLedgerEntry."Document No.";
        if not ((CustomerLedgerEntry."Document Type" = "Gen. Journal Document Type"::Payment) or (CustomerLedgerEntry."Document Type" = "Gen. Journal Document Type"::Refund)) then
            CustomerLedgerEntry.Modify();
        GLEntries.SetRange("Document No.", CustomerLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", CustomerLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll(Paid, true);
            GLEntries.ModifyAll("Pmt Cancelled", false);
            GLEntries.ModifyAll("Bank Posting Date", BankLedgerEntry."Posting Date");
            GLEntries.ModifyAll("Bank Document No.", BankLedgerEntry."Document No.");
            if not (BankLedgerEntry."Posting Date" = 0D) then begin
                GLEntries.ModifyAll("Vend./Cust. Doc. No.", CustomerLedgerEntry."Document No.");
                GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", CustomerLedgerEntry."Due Date");
            end else begin
                GLEntries.ModifyAll("Vend./Cust. Doc. No.", '');
                GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", 0D);
                GLEntries.ModifyAll(Paid, false);
                GLEntries.ModifyAll("Pmt Cancelled", true);
            end;
        end;
    end;

    // Helper methods

    local procedure GetBankLedgerEntry(var PaymentLedgerEntry: Record "Cust. Ledger Entry"): Record "Bank Account Ledger Entry"
    // ISSUE: Method needs testing.
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        BankLedgerEntry.SetRange("Transaction No.", PaymentLedgerEntry."Transaction No.");
        BankLedgerEntry.SetRange("Posting Date", PaymentLedgerEntry."Posting Date");
        BankLedgerEntry.SetRange("Document No.", PaymentLedgerEntry."Document No.");
        BankLedgerEntry.SetRange("Bal. Account No.", PaymentLedgerEntry."Customer No.");
        if BankLedgerEntry.Count > 1 then
            Error('Found more than 1 Bank Ledger Entry.');
        if BankLedgerEntry.FindFirst() then
            exit(BankLedgerEntry)
        else begin
            Clear(BankLedgerEntry);
            exit(BankLedgerEntry);
        end;
    end;

}
