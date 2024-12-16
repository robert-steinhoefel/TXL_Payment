namespace RST.TXL_Payment;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Purchases.Payables;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;

codeunit 51001 "Vendor Ledger Entries"
{

    TableNo = "Detailed Vendor Ledg. Entry";
    Permissions = tabledata "G/L Entry" = rm;

    trigger OnRun()
    begin
        if Rec."Entry Type" <> "Detailed CV Ledger Entry Type"::Application then
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
        if Rec."Vendor Ledger Entry No." <> Rec."Applied Vend. Ledger Entry No." then begin
            // The Invoice Ledger Entry
        end;

        if Rec."Vendor Ledger Entry No." = Rec."Applied Vend. Ledger Entry No." then begin
            // How do we know that we have a posting application or an un-application?
            // This detailed entry lead to the payment Entry.
            PmtDLEHelperEntry.SetRange("Applied Vend. Ledger Entry No.", Rec."Applied Vend. Ledger Entry No.");
            PmtDLEHelperEntry.SetFilter("Vendor Ledger Entry No.", '<>%1', Rec."Vendor Ledger Entry No.");
            PmtDLEHelperEntry.SetRange(Unapplied, false);
            if PmtDLEHelperEntry.Count > 1 then
                Error('More than one Payment entry found.');
            if PmtDLEHelperEntry.FindFirst() then begin
                PaymentLedgerEntry.SetRange("Entry No.", PmtDLEHelperEntry."Vendor Ledger Entry No.");
                PaymentLedgerEntry.SetRange("Document Type", "Gen. Journal Document Type"::Payment);
                if PaymentLedgerEntry.FindSet() then begin
                    if PaymentLedgerEntry.Count() > 1 then
                        Error('More than one Payment entry found.');
                    BankLedgerEntry := GetBankLedgerEntry(PaymentLedgerEntry);
                    if BankLedgerEntry.IsEmpty then begin
                        BankLedgerEntry.Init();
                        BankLedgerEntry."Posting Date" := Rec."Posting Date";
                        BankLedgerEntry."Document No." := Rec."Document No.";
                    end;
                end;
                DetailedVendLedgerEntry.SetRange("Applied Vend. Ledger Entry No.", Rec."Applied Vend. Ledger Entry No.");
                DetailedVendLedgerEntry.SetFilter("Vendor Ledger Entry No.", '<>%1', Rec."Applied Vend. Ledger Entry No.");
                if DetailedVendLedgerEntry.FindSet() then
                    repeat
                        InvoiceLedgerEntry.Get(DetailedVendLedgerEntry."Vendor Ledger Entry No.");
                        GetAndSetGLEntriesPaid(BankLedgerEntry, InvoiceLedgerEntry);
                    until DetailedVendLedgerEntry.Next() = 0;
                // VendorLedgerEntry.Get(DetailedVendLedgerEntry."Vendor Ledger Entry No.");
                // InvoiceLedgerEntry := GetInvoiceLedgerEntry(Rec);
            end else if Rec.Unapplied = true then begin
                DetailedVendLedgerEntry.SetRange("Applied Vend. Ledger Entry No.", Rec."Applied Vend. Ledger Entry No.");
                DetailedVendLedgerEntry.SetFilter("Vendor Ledger Entry No.", '<>%1', Rec."Applied Vend. Ledger Entry No.");
                if DetailedVendLedgerEntry.FindSet() then
                    repeat
                        InvoiceLedgerEntry.Get(DetailedVendLedgerEntry."Vendor Ledger Entry No.");
                        GetAndSetGLEntriesUnPaid(InvoiceLedgerEntry);
                    until DetailedVendLedgerEntry.Next() = 0;
            end;
        end;
    end;

    local procedure GetAndSetGLEntriesPaid(var BankLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        GLEntries: Record "G/L Entry";
    begin
        VendorLedgerEntry.Paid := true;
        VendorLedgerEntry."Bank Posting Date" := BankLedgerEntry."Posting Date";
        VendorLedgerEntry."Bank Document No." := BankLedgerEntry."Document No.";
        VendorLedgerEntry.Modify();
        GLEntries.SetRange("Document No.", VendorLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", VendorLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll(Paid, true);
            GLEntries.ModifyAll("Bank Posting Date", BankLedgerEntry."Posting Date");
            GLEntries.ModifyAll("Bank Document No.", BankLedgerEntry."Document No.");
            GLEntries.ModifyAll("Vend./Cust. Doc. No.", VendorLedgerEntry."Document No.");
            GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", VendorLedgerEntry."Due Date");
        end;
    end;

    local procedure GetAndSetGLEntriesUnPaid(var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        GLEntries: Record "G/L Entry";
    begin
        VendorLedgerEntry.Paid := false;
        VendorLedgerEntry."Pmt Cancelled" := true;
        VendorLedgerEntry."Bank Posting Date" := 0D;
        VendorLedgerEntry."Bank Document No." := '';
        VendorLedgerEntry.Modify();
        GLEntries.SetRange("Document No.", VendorLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", VendorLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll(Paid, false);
            GLEntries.ModifyAll("Pmt Cancelled", true);
            GLEntries.ModifyAll("Bank Posting Date", 0D);
            GLEntries.ModifyAll("Bank Document No.", '');
            GLEntries.ModifyAll("Vend./Cust. Doc. No.", '');
            GLEntries.ModifyAll("Vend./Cust. Doc. Due Date", 0D);
        end;
    end;

    // Helper methods

    local procedure GetBankLedgerEntry(var PaymentLedgerEntry: Record "Vendor Ledger Entry"): Record "Bank Account Ledger Entry"
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

    local procedure GetInvoiceLedgerEntry(var Rec: Record "Detailed Vendor Ledg. Entry"): Record "Vendor Ledger Entry"
    var
        DetailedVendLedgerEntry: Record "Detailed Vendor Ledg. Entry";
        VendorLedgerEntry: Record "Vendor Ledger Entry";
    begin
        DetailedVendLedgerEntry.SetRange("Applied Vend. Ledger Entry No.", Rec."Applied Vend. Ledger Entry No.");
        DetailedVendLedgerEntry.SetFilter("Vendor Ledger Entry No.", '<>%1', Rec."Applied Vend. Ledger Entry No.");
        DetailedVendLedgerEntry.FindFirst();
        VendorLedgerEntry.Get(DetailedVendLedgerEntry."Vendor Ledger Entry No.");
        exit(VendorLedgerEntry);
    end;

}
