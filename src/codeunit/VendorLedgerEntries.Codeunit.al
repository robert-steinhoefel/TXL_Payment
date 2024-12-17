namespace RST.TXL_Payment;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Purchases.Payables;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;

codeunit 51001 "Vendor Ledger Entries"
{

    TableNo = "Detailed Vendor Ledg. Entry";
    Permissions = tabledata "G/L Entry" = rm,
    tabledata "Vendor Ledger Entry" = rm;

    trigger OnRun()
    begin
        if not (Rec."Entry Type" = "Detailed CV Ledger Entry Type"::Application) then
            exit;
        ProcessLedgerEntries(Rec);
    end;

    local procedure ProcessLedgerEntries(var Rec: Record "Detailed Vendor Ledg. Entry")
    var
        DetailedVendLedgerEntry, PmtDLEHelperEntry : Record "Detailed Vendor Ledg. Entry";
        InvoiceLedgerEntry: Record "Vendor Ledger Entry";
        PaymentLedgerEntry, PmtLEHelperEntry : Record "Vendor Ledger Entry";
        BankLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        if (Rec."Initial Document Type" = "Gen. Journal Document Type"::Invoice) or (Rec."Initial Document Type" = "Gen. Journal Document Type"::"Credit Memo") then begin
            // We don't know if we come from payment or invoice entry.
            PmtDLEHelperEntry.SetRange("Applied Vend. Ledger Entry No.", Rec."Applied Vend. Ledger Entry No.");
            PmtDLEHelperEntry.SetFilter("Vendor Ledger Entry No.", '<>%1', Rec."Vendor Ledger Entry No.");
            PmtDLEHelperEntry.SetRange(Unapplied, false);
            // When multiple invoice/credit memo ledger entries are applied to one payment entry, it does not matter, which ledger entry we follow to get the payment details.
            // ISSUE: What if multiple payment entries are applied to the same invoice / credit memo entry.
            if PmtDLEHelperEntry.FindFirst() then begin
                PaymentLedgerEntry.SetRange("Entry No.", PmtDLEHelperEntry."Vendor Ledger Entry No.");
                PaymentLedgerEntry.SetRange("Document Type", "Gen. Journal Document Type"::Payment);
                if PaymentLedgerEntry.FindSet() then begin
                    if PaymentLedgerEntry.Count() > 1 then
                        Error('More than one Payment entry found.');
                    BankLedgerEntry := GetBankLedgerEntry(PaymentLedgerEntry);
                end;
            end;
            if BankLedgerEntry.IsEmpty then begin
                BankLedgerEntry.Init();
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
    end;

    local procedure GetAndSetGLEntriesPaid(var BankLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        GLEntries: Record "G/L Entry";
    begin
        // ISSUE: What about partial payments to ledger entries?
        if not (BankLedgerEntry."Posting Date" = 0D) then begin
            VendorLedgerEntry.Paid := true;
            VendorLedgerEntry."Pmt Cancelled" := false;
        end else begin
            VendorLedgerEntry.Paid := false;
            VendorLedgerEntry."Pmt Cancelled" := true;
        end;
        VendorLedgerEntry."Bank Posting Date" := BankLedgerEntry."Posting Date";
        VendorLedgerEntry."Bank Document No." := BankLedgerEntry."Document No.";
        if not (VendorLedgerEntry."Document Type" = "Gen. Journal Document Type"::Payment) then
            VendorLedgerEntry.Modify();
        GLEntries.SetRange("Document No.", VendorLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", VendorLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll(Paid, true);
            GLEntries.ModifyAll("Pmt Cancelled", false);
            GLEntries.ModifyAll("Bank Posting Date", BankLedgerEntry."Posting Date");
            GLEntries.ModifyAll("Bank Document No.", BankLedgerEntry."Document No.");
            if not (BankLedgerEntry."Posting Date" = 0D) then begin
                GLEntries.ModifyAll("Vend./Cust. Doc. No.", VendorLedgerEntry."Document No.");
                GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", VendorLedgerEntry."Due Date");
            end else begin
                GLEntries.ModifyAll("Vend./Cust. Doc. No.", '');
                GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", 0D);
                GLEntries.ModifyAll(Paid, false);
                GLEntries.ModifyAll("Pmt Cancelled", true);
            end;
        end;
    end;

    // Helper methods

    local procedure GetBankLedgerEntry(var PaymentLedgerEntry: Record "Vendor Ledger Entry"): Record "Bank Account Ledger Entry"
    // ISSUE: Method needs testing.
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        BankLedgerEntry.SetRange("Transaction No.", PaymentLedgerEntry."Transaction No.");
        BankLedgerEntry.SetRange("Posting Date", PaymentLedgerEntry."Posting Date");
        BankLedgerEntry.SetRange("Document No.", PaymentLedgerEntry."Document No.");
        BankLedgerEntry.SetRange("Bal. Account No.", PaymentLedgerEntry."Vendor No.");
        if BankLedgerEntry.Count > 1 then
            Error('Found more than 1 Bank Ledger Entry.');
        if BankLedgerEntry.FindFirst() then
            exit(BankLedgerEntry);
    end;
}
