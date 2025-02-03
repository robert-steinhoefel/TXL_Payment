namespace P3.TXL.Payment.BankAccount;

using P3.TXL.Payment.Vendor;
using P3.TXL.Payment.Customer;
using P3.TXL.Payment.System;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.Dimension;
using Microsoft.Purchases.Payables;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Sales.Receivables;

codeunit 51104 "Bank Account Ledger Entries"
{
    TableNo = "Bank Account Ledger Entry";
    Permissions = tabledata "Bank Account Ledger Entry" = rm,
    tabledata "Vendor Ledger Entry" = r,
    tabledata "Cust. Ledger Entry" = r,
    tabledata "Detailed Vendor Ledg. Entry" = r,
    tabledata "Detailed Cust. Ledg. Entry" = r,
    tabledata Dimension = r,
    tabledata "Dimension Set Entry" = r;

    trigger OnRun()
    begin
        GetAndProcessLedgerEntries(Rec);
    end;

    local procedure GetAndProcessLedgerEntries(var Rec: Record "Bank Account Ledger Entry")
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        CustomerLederEntry: Record "Cust. Ledger Entry";
        GeneralLedgerEntries: Record "G/L Entry";
        ErrNoDirectPosting: Label 'Poting payments directly to %1s is not allowed in cameralistics. Use an invoice or credit memo on a customer or vendor instead.';
    begin
        case Rec."Bal. Account Type" of
            "Gen. Journal Account Type"::Vendor:
                begin
                    VendorLedgerEntry.SetRange("Transaction No.", Rec."Transaction No.");
                    // TODO: Is it definite that there will only be 1 Vendor Ledger Entry per Bank Ledger Entry? What if 1 BLE balances multiple VLE?
                    if VendorLedgerEntry.FindFirst() then begin
                        SetVendLedgEntryDetailsOnBankLedgEntry(Rec, VendorLedgerEntry);
                    end;
                end;
            "Gen. Journal Account Type"::Customer:
                begin
                    CustomerLederEntry.SetRange("Transaction No.", Rec."Transaction No.");
                    // TODO: Is it definite that there will only be 1 Customer Ledger Entry per Bank Ledger Entry? What if 1 BLE balances multiple CLE?
                    if CustomerLederEntry.FindFirst() then begin
                        SetCustLedgEntryDetailsOnBankLedgEntry(Rec, CustomerLederEntry)
                    end;
                end;
            "Gen. Journal Account Type"::"G/L Account":
                begin
                    Rec."Ledger Entry Type" := "Source Ledger Entry Type"::"G/L Account";
                    Rec."CV Doc Type" := Rec."Document Type";
                    Rec."CV Doc. Due Date" := Rec."Posting Date";
                    Rec."CV Doc. No." := Rec."Document No.";
                    Rec."CV Global Dimension 1 Code" := Rec."Global Dimension 1 Code";
                    Rec."CV Global Dimension 2 Code" := Rec."Global Dimension 2 Code";
                    Rec."CV Dimension Set ID" := Rec."Dimension Set ID";
                    Rec.Modify();
                end;
            "Gen. Journal Account Type"::"Fixed Asset":
                Error(StrSubstNo(ErrNoDirectPosting, Rec."Bal. Account Type"));
            "Gen. Journal Account Type"::Employee:
                Error(StrSubstNo(ErrNoDirectPosting, Rec."Bal. Account Type"));
            "Gen. Journal Account Type"::"IC Partner":
                Error(StrSubstNo(ErrNoDirectPosting, Rec."Bal. Account Type"));
            "Gen. Journal Account Type"::"Allocation Account":
                Error(StrSubstNo(ErrNoDirectPosting, Rec."Bal. Account Type"));
            "Gen. Journal Account Type"::"Bank Account":
                Error(StrSubstNo(ErrNoDirectPosting, Rec."Bal. Account Type"));
        end;
    end;

    local procedure SetVendLedgEntryDetailsOnBankLedgEntry(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        DetailedVendorLedgerEntry: Record "Detailed Vendor Ledg. Entry";
        DocVendLedgEntry: Record "Vendor Ledger Entry";
        VendorLedgerEntriesProcessing: Codeunit "Vendor Ledger Entries";
    begin
        DetailedVendorLedgerEntry.SetRange("Applied Vend. Ledger Entry No.", VendorLedgerEntry."Entry No.");
        DetailedVendorLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        DetailedVendorLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Invoice, "Gen. Journal Document Type"::"Credit Memo");
        if DetailedVendorLedgerEntry.FindSet() then
            repeat
                DocVendLedgEntry.Get(DetailedVendorLedgerEntry."Vendor Ledger Entry No.");
                if BankAccountLedgerEntry."CV Doc. No." <> '' then begin
                    BankAccountLedgerEntry."CV Doc. No." := BankAccountLedgerEntry."CV Doc. No." + '|' + DocVendLedgEntry."Document No.";
                    if BankAccountLedgerEntry."CV Doc. Due Date" < DocVendLedgEntry."Due Date" then
                        BankAccountLedgerEntry."CV Doc. Due Date" := DocVendLedgEntry."Due Date";
                end else begin
                    BankAccountLedgerEntry."CV Doc. No." := DocVendLedgEntry."Document No.";
                    BankAccountLedgerEntry."CV Doc. Due Date" := DocVendLedgEntry."Due Date"
                end;
                BankAccountLedgerEntry."Ledger Entry Type" := "Source Ledger Entry Type"::Vendor;
                BankAccountLedgerEntry."CV Doc Type" := DocVendLedgEntry."Document Type";
                BankAccountLedgerEntry."CV Global Dimension 1 Code" := DocVendLedgEntry."Global Dimension 1 Code";
                BankAccountLedgerEntry."CV Global Dimension 2 Code" := DocVendLedgEntry."Global Dimension 2 Code";
                BankAccountLedgerEntry."CV Dimension Set ID" := DocVendLedgEntry."Dimension Set ID";
                // VendorLedgerEntriesProcessing.SetPaymentDetails(BankAccountLedgerEntry, DocVendLedgEntry);
                // DocVendLedgEntry.Modify();
                // TODO: Explicitely test what if there are multiple VendorLedgerEntries being balanced? Won't work in BC base, but maybe through extensions like OPPlus or Megabau.
                BankAccountLedgerEntry.Modify();
            until DetailedVendorLedgerEntry.Next() = 0;
    end;

    local procedure SetCustLedgEntryDetailsOnBankLedgEntry(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry"; var CustomerLedgerEntry: Record "Cust. Ledger Entry")
    var
        DetailedCustomerLedgerEntry: Record "Detailed Cust. Ledg. Entry";
        DocCustomerLedgEntry: Record "Cust. Ledger Entry";
        CustomerLedgerEntriesProcessing: Codeunit "Customer Ledger Entries";
    begin
        DetailedCustomerLedgerEntry.SetRange("Applied Cust. Ledger Entry No.", CustomerLedgerEntry."Entry No.");
        DetailedCustomerLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        DetailedCustomerLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Invoice, "Gen. Journal Document Type"::"Credit Memo");
        if DetailedCustomerLedgerEntry.FindSet() then
            repeat
                DocCustomerLedgEntry.Get(DetailedCustomerLedgerEntry."Cust. Ledger Entry No.");
                if BankAccountLedgerEntry."CV Doc. No." <> '' then begin
                    BankAccountLedgerEntry."CV Doc. No." := BankAccountLedgerEntry."CV Doc. No." + '|' + DocCustomerLedgEntry."Document No.";
                    if BankAccountLedgerEntry."CV Doc. Due Date" < DocCustomerLedgEntry."Due Date" then
                        BankAccountLedgerEntry."CV Doc. Due Date" := DocCustomerLedgEntry."Due Date";
                end else begin
                    BankAccountLedgerEntry."CV Doc. No." := DocCustomerLedgEntry."Document No.";
                    BankAccountLedgerEntry."CV Doc. Due Date" := DocCustomerLedgEntry."Due Date"
                end;
                BankAccountLedgerEntry."Ledger Entry Type" := "Source Ledger Entry Type"::Customer;
                BankAccountLedgerEntry."CV Doc Type" := DocCustomerLedgEntry."Document Type";
                BankAccountLedgerEntry."CV Global Dimension 1 Code" := DocCustomerLedgEntry."Global Dimension 1 Code";
                BankAccountLedgerEntry."CV Global Dimension 2 Code" := DocCustomerLedgEntry."Global Dimension 2 Code";
                BankAccountLedgerEntry."CV Dimension Set ID" := DocCustomerLedgEntry."Dimension Set ID";
                // CustomerLedgerEntriesProcessing.SetPaymentDetails(BankAccountLedgerEntry, DocCustomerLedgEntry);
                // DocCustomerLedgEntry.Modify();
                // TODO: Explicitely test what if there are multiple CustomerLedgerEntries being balanced? Won't work in BC base, but maybe through extensions like OPPlus or Megabau.
                BankAccountLedgerEntry.Modify();
            until DetailedCustomerLedgerEntry.Next() = 0;
    end;

}
