namespace P3.TXL.Payment.BankAccount;

using Microsoft.Bank.Ledger;
using Microsoft.Finance.Dimension;
using P3.TXL.Payment.System;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Purchases.Payables;
using Microsoft.Sales.Receivables;
using Microsoft.Finance.GeneralLedger.Ledger;

tableextension 51104 "Bank Acc. Ledger Entry" extends "Bank Account Ledger Entry"
{
    fields
    {
        field(51100; "Ledger Entry Type"; Enum "Source Ledger Entry Type")
        {
            Caption = 'Source Ledger Entry Type';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51101; "CV Doc. No."; Code[20])
        {
            Caption = 'Vendor/Customer Document No.';
            DataClassification = ToBeClassified;
            Editable = false;
            TableRelation =
            if ("Ledger Entry Type" = const("Source Ledger Entry Type"::Customer)) "Cust. Ledger Entry"."Document No." where("Document No." = field("CV Doc. No."))
            else
            if ("Ledger Entry Type" = const("Source Ledger Entry Type"::Vendor)) "Vendor Ledger Entry"."Document No." where("Document No." = field("CV Doc. No."));
        }
        field(51102; "CV Doc. Due Date"; Date)
        {
            Caption = 'Vendor/Customer Document Due Date';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51103; "CV Doc Type"; Enum "Gen. Journal Document Type")
        {
            Caption = 'Vendor/Customer Document Type';
            Editable = false;
            // TableRelation =
            // if ("Ledger Entry Type" = const("Source Ledger Entry Type"::Customer)) "Cust. Ledger Entry"."Document Type" where("Document No." = field("CV Doc. No."))
            // else
            // if ("Ledger Entry Type" = const("Source Ledger Entry Type"::Vendor)) "Vendor Ledger Entry"."Document Type" where("Document No." = field("CV Doc. No."))
            // else
            // // FIXME: Probably not working properly since we're pretty sure that there will be more than 1 G/L entries.
            // if ("Ledger Entry Type" = const("Source Ledger Entry Type"::"G/L Account")) "G/L Entry"."Document Type" where("Document No." = field("CV Doc. No."));
        }
        field(51104; "CV Global Dimension 1 Code"; Code[10])
        {
            Caption = 'Vendor/Customer Global Dimension 1 Code';
            Editable = false;
            TableRelation = Dimension;
        }
        field(51105; "CV Global Dimension 2 Code"; Code[10])
        {
            Caption = 'Vendor/Customer Global Dimension 2 Code';
            Editable = false;
            TableRelation = Dimension;
        }
        field(51106; "CV Dimension Set ID"; Integer)
        {
            Caption = 'Vendor/Customer Dimension Set ID';
            Editable = false;
            TableRelation = "Dimension Set Entry";
        }
    }
}
