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
    var
        LedgerEntry: Variant;
    begin
        GetAndProcessLedgerEntries(Rec, LedgerEntry);
    end;

    procedure GetAndProcessLedgerEntries(var Rec: Record "Bank Account Ledger Entry"; var LedgerEntry: Variant)
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        CustomerLederEntry: Record "Cust. Ledger Entry";
        GeneralLedgerEntry: Record "G/L Entry";
        LedgerEntryRecRef: RecordRef;
        ErrNoDirectPosting: Label 'Poting payments directly to %1s is not allowed in cameralistics. Use an invoice or credit memo on a customer or vendor instead.';
    begin
        if Rec."Entry No." = 0 then
            exit;

        LedgerEntryRecRef.GetTable(LedgerEntry);
        case LedgerEntryRecRef.Number() of
            17:
                GeneralLedgerEntry := LedgerEntry;
            21:
                CustomerLederEntry := LedgerEntry;
            25:
                VendorLedgerEntry := LedgerEntry;

        end;

        case Rec."Bal. Account Type" of
            "Gen. Journal Account Type"::Vendor:
                begin
                    SetVendLedgEntryDetailsOnBankLedgEntry(Rec, VendorLedgerEntry);
                    // end;
                end;
            "Gen. Journal Account Type"::Customer:
                begin
                    SetCustLedgEntryDetailsOnBankLedgEntry(Rec, CustomerLederEntry)
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

    procedure GetAndProcessLedgerEntries(var Rec: Record "Bank Account Ledger Entry"; Unapplied: Boolean)
    var
    begin
        if Unapplied then begin
            Rec."Ledger Entry Type" := "Source Ledger Entry Type"::" ";
            Rec."CV Doc Type" := "Gen. Journal Document Type"::" ";
            Rec."CV Doc. Due Date" := 0D;
            Rec."CV Doc. No." := '';
            Rec."CV Global Dimension 1 Code" := '';
            Rec."CV Global Dimension 2 Code" := '';
            Rec."CV Dimension Set ID" := 0;
            Rec.Modify();
        end;
    end;

    local procedure SetVendLedgEntryDetailsOnBankLedgEntry(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        DetailedVendorLedgerEntry: Record "Detailed Vendor Ledg. Entry";
        // VendorLedgerEntry: Record "Vendor Ledger Entry";
        FilterVLE: Record "Vendor Ledger Entry";
    begin
        // DetailedVendorLedgerEntry.SetRange("Applied Vend. Ledger Entry No.", VendorLedgerEntry."Entry No.");
        // DetailedVendorLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
        // DetailedVendorLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Invoice, "Gen. Journal Document Type"::"Credit Memo");
        // if DetailedVendorLedgerEntry.FindSet() then

        // FilterVLE.SetRange("Transaction No.", VendorLedgerEntry."Transaction No.");
        // if FilterVLE.FindSet() then
        //     repeat
        // VendorLedgerEntry.Get(DetailedVendorLedgerEntry."Vendor Ledger Entry No.");

        if BankAccountLedgerEntry."CV Doc. No." <> '' then begin
            BankAccountLedgerEntry."CV Doc. No." := BankAccountLedgerEntry."CV Doc. No." + '|' + VendorLedgerEntry."Document No.";
            if BankAccountLedgerEntry."CV Doc. Due Date" < VendorLedgerEntry."Due Date" then
                BankAccountLedgerEntry."CV Doc. Due Date" := VendorLedgerEntry."Due Date";
        end else begin
            BankAccountLedgerEntry."CV Doc. No." := VendorLedgerEntry."Document No.";
            BankAccountLedgerEntry."CV Doc. Due Date" := VendorLedgerEntry."Due Date"
        end;
        BankAccountLedgerEntry."Ledger Entry Type" := "Source Ledger Entry Type"::Vendor;
        BankAccountLedgerEntry."CV Doc Type" := VendorLedgerEntry."Document Type";
        BankAccountLedgerEntry."CV Global Dimension 1 Code" := VendorLedgerEntry."Global Dimension 1 Code";
        BankAccountLedgerEntry."CV Global Dimension 2 Code" := VendorLedgerEntry."Global Dimension 2 Code";
        BankAccountLedgerEntry."CV Dimension Set ID" := VendorLedgerEntry."Dimension Set ID";
        // TODO: Explicitely test what if there are multiple VendorLedgerEntries being balanced? Won't work in BC base, but maybe through extensions like OPPlus or Megabau.
        BankAccountLedgerEntry.Modify();
        // until DetailedVendorLedgerEntry.Next() = 0;
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
                // TODO: Explicitely test what if there are multiple CustomerLedgerEntries being balanced? Won't work in BC base, but maybe through extensions like OPPlus or Megabau.
                BankAccountLedgerEntry.Modify();
            until DetailedCustomerLedgerEntry.Next() = 0;
    end;

}
