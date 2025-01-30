namespace P3.TXL.Payment.Vendor;

using Microsoft.Purchases.Payables;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;

codeunit 51102 "Vendor Ledger Entries"
{
    TableNo = "Detailed Vendor Ledg. Entry";
    Permissions = tabledata "Bank Account Ledger Entry" = r,
                    tabledata "Detailed Vendor Ledg. Entry" = r,
                    tabledata "G/L Entry" = rm,
                    tabledata "Vendor Ledger Entry" = rm;

    trigger OnRun()
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
        InvoiceLedgerEntry: Record "Vendor Ledger Entry";
    begin
        BankLedgerEntry := GetBankLedgerEntry(Rec);
        if (BankLedgerEntry."Entry No." = 0) then begin
            if not Rec.Unapplied = true then begin
                // If payment is has not been posted through bank account, we'll use the vendor's payment ledger entry data.
                // If posting is an un-application, these fields will remain empty - on purpose.
                BankLedgerEntry."Posting Date" := Rec."Posting Date";
                BankLedgerEntry."Document No." := Rec."Document No.";
            end;
        end;
        InvoiceLedgerEntry.Get(Rec."Vendor Ledger Entry No.");
        GetAndSetGLEntriesPaid(BankLedgerEntry, InvoiceLedgerEntry);
    end;

    local procedure GetAndSetGLEntriesPaid(var BankLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        GLEntries: Record "G/L Entry";
    begin
        // ISSUE: What about partial payments to ledger entries?
        // ISSUE: When an invoice is being applied to two payments and one of those payments is cancelled, the entry is not modified.
        if not (BankLedgerEntry."Posting Date" = 0D) then begin
            VendorLedgerEntry.Paid := true;
            VendorLedgerEntry."Pmt Cancelled" := false;
        end else begin
            VendorLedgerEntry.Paid := false;
            VendorLedgerEntry."Pmt Cancelled" := true;
        end;
        VendorLedgerEntry."Bank Posting Date" := BankLedgerEntry."Posting Date";
        VendorLedgerEntry."Bank Document No." := BankLedgerEntry."Document No.";
        if not ((VendorLedgerEntry."Document Type" = "Gen. Journal Document Type"::Payment) or (VendorLedgerEntry."Document Type" = "Gen. Journal Document Type"::Refund)) then
            VendorLedgerEntry.Modify();
        GLEntries.SetRange("Document No.", VendorLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", VendorLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll("Bank Posting Date", BankLedgerEntry."Posting Date");
            GLEntries.ModifyAll("Bank Document No.", BankLedgerEntry."Document No.");
            if not (BankLedgerEntry."Posting Date" = 0D) then begin
                GLEntries.ModifyAll("Vend./Cust. Doc. No.", VendorLedgerEntry."Document No.");
                GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", VendorLedgerEntry."Due Date");
                GLEntries.ModifyAll(Paid, true);
                GLEntries.ModifyAll("Pmt Cancelled", false);
            end else begin
                GLEntries.ModifyAll("Vend./Cust. Doc. No.", '');
                GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", 0D);
                GLEntries.ModifyAll(Paid, false);
                GLEntries.ModifyAll("Pmt Cancelled", true);
            end;
        end;
    end;

    // procedure SetPaymentDetails(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    // var
    //     GLEntries: Record "G/L Entry";
    // begin
    //     VendorLedgerEntry."Bank Posting Date" := BankAccountLedgerEntry."Posting Date";
    //     VendorLedgerEntry."Bank Document No." := BankAccountLedgerEntry."Document No.";
    //     VendorLedgerEntry.Paid := true;
    //     GLEntries.SetRange("Document No.", VendorLedgerEntry."Document No.");
    //     GLEntries.SetRange("Posting Date", VendorLedgerEntry."Posting Date");
    //     if not GLEntries.IsEmpty then begin
    //         GLEntries.ModifyAll(Paid, true);
    //         GLEntries.ModifyAll("Pmt Cancelled", false);
    //         GLEntries.ModifyAll("Bank Posting Date", BankAccountLedgerEntry."Posting Date");
    //         GLEntries.ModifyAll("Bank Document No.", BankAccountLedgerEntry."Document No.");
    //         GLEntries.ModifyAll("Vend./Cust. Doc. No.", VendorLedgerEntry."Document No.");
    //         GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", VendorLedgerEntry."Due Date");
    //     end;
    // end;

    // Helper methods

    local procedure GetBankLedgerEntry(var DetailedVendorLedgEntry: Record "Detailed Vendor Ledg. Entry"): Record "Bank Account Ledger Entry"
    // ISSUE: Method needs testing.
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        BankLedgerEntry.SetRange("Posting Date", DetailedVendorLedgEntry."Posting Date");
        BankLedgerEntry.SetRange("Document No.", DetailedVendorLedgEntry."Document No.");
        BankLedgerEntry.SetRange("Bal. Account No.", DetailedVendorLedgEntry."Vendor No.");
        BankLedgerEntry.SetRange("Amount (LCY)", (DetailedVendorLedgEntry."Amount (LCY)" * -1));
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
