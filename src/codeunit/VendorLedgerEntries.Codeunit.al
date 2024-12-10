namespace RST.TXL_Payment;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Purchases.Payables;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;

codeunit 51001 "Vendor Ledger Entries"
{

    TableNo = "Detailed Vendor Ledg. Entry";

    trigger OnRun()
    begin
        if Rec."Entry Type" <> "Detailed CV Ledger Entry Type"::Application then
            exit;
        ProcessLedgerEntries(Rec);
    end;

    local procedure ProcessLedgerEntries(var Rec: Record "Detailed Vendor Ledg. Entry")
    var
        InvoiceLedgerEntry: Record "Vendor Ledger Entry";
        PaymentLedgerEntry: Record "Vendor Ledger Entry";
        BankLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        // if Rec."Vendor Ledger Entry No." <> Rec."Applied Vend. Ledger Entry No." then exit;

        if Rec."Vendor Ledger Entry No." = Rec."Applied Vend. Ledger Entry No." then begin
            // How do we know that we have a posting application or an un-application?
            // This detailed entry lead to the payment Entry.
            PaymentLedgerEntry.SetRange("Entry No.", Rec."Applied Vend. Ledger Entry No.");
            PaymentLedgerEntry.SetRange("Document Type", "Gen. Journal Document Type"::Payment);
            if PaymentLedgerEntry.FindFirst() then begin
                BankLedgerEntry := GetBankLedgerEntry(PaymentLedgerEntry);
            end;
            InvoiceLedgerEntry := GetInvoiceLedgerEntry(Rec);
        end;
    end;

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
        BankLedgerEntry.FindFirst();
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
