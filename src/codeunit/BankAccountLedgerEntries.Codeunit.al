namespace P3.TXL.Payment.BankAccount;

using P3.TXL.Payment.System;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.Dimension;
using Microsoft.Purchases.Payables;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;
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

    procedure UnApplyLedgerEntries(var Rec: Record "Bank Account Ledger Entry"; Unapplied: Boolean)
    var
    begin
        if Rec."Entry No." = 0 then
            exit;
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
        DocumentNo: Text;
    begin
        if BankAccountLedgerEntry."CV Doc. No." <> '' then begin
            if StrPos(BankAccountLedgerEntry."CV Doc. No.", VendorLedgerEntry."Document No.") > 0 then
                exit;
            DocumentNo := BankAccountLedgerEntry."CV Doc. No." + '|' + VendorLedgerEntry."Document No.";
            if StrLen(DocumentNo) > 20 then
                DocumentNo := DocumentNo.Remove(1, (StrLen(DocumentNo) - 20));
            BankAccountLedgerEntry."CV Doc. No." := DocumentNo;
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
        // TODO: When an unapplication is started through user action, the Bank Ledger entry will be modified BEFORE the unapplication has been posted. Meaning: When unapplication then is cancelled, the CV Doc. No. will be specified twice.
        BankAccountLedgerEntry.Modify();
    end;

    local procedure SetCustLedgEntryDetailsOnBankLedgEntry(var BankAccountLedgerEntry: Record "Bank Account Ledger Entry"; var CustomerLedgerEntry: Record "Cust. Ledger Entry")
    var
        DetailedCustomerLedgerEntry: Record "Detailed Cust. Ledg. Entry";
        DocumentNo: Text;
    begin
        if BankAccountLedgerEntry."CV Doc. No." <> '' then begin
            if StrPos(BankAccountLedgerEntry."CV Doc. No.", CustomerLedgerEntry."Document No.") > 0 then
                exit;
            DocumentNo := BankAccountLedgerEntry."CV Doc. No." + '|' + CustomerLedgerEntry."Document No.";
            if StrLen(DocumentNo) > 20 then
                DocumentNo := DocumentNo.Remove(1, (StrLen(DocumentNo) - 20));
            BankAccountLedgerEntry."CV Doc. No." := DocumentNo;
            if BankAccountLedgerEntry."CV Doc. Due Date" < CustomerLedgerEntry."Due Date" then
                BankAccountLedgerEntry."CV Doc. Due Date" := CustomerLedgerEntry."Due Date";
        end else begin
            BankAccountLedgerEntry."CV Doc. No." := CustomerLedgerEntry."Document No.";
            BankAccountLedgerEntry."CV Doc. Due Date" := CustomerLedgerEntry."Due Date"
        end;
        BankAccountLedgerEntry."Ledger Entry Type" := "Source Ledger Entry Type"::Customer;
        BankAccountLedgerEntry."CV Doc Type" := CustomerLedgerEntry."Document Type";
        BankAccountLedgerEntry."CV Global Dimension 1 Code" := CustomerLedgerEntry."Global Dimension 1 Code";
        BankAccountLedgerEntry."CV Global Dimension 2 Code" := CustomerLedgerEntry."Global Dimension 2 Code";
        BankAccountLedgerEntry."CV Dimension Set ID" := CustomerLedgerEntry."Dimension Set ID";
        // TODO: Explicitely test what if there are multiple CustomerLedgerEntries being balanced? Won't work in BC base, but maybe through extensions like OPPlus or Megabau.
        BankAccountLedgerEntry.Modify();
    end;

}
