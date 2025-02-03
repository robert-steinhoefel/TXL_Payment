namespace P3.TXL.Payment.Vendor;

using Microsoft.Purchases.Payables;

tableextension 51101 "VendorLedgerEntry TableExt" extends "Vendor Ledger Entry"
{
    fields
    {
        field(51100; "Paid"; Boolean)
        {
            Caption = 'Paid';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51101; "Pmt Cancelled"; Boolean)
        {
            Caption = 'Payment Cancelled';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51102; "Bank Posting Date"; Date)
        {
            Caption = 'Bank Posting Date';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51103; "Bank Document No."; Code[20])
        {
            Caption = 'Bank Document No.';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51104; "CV Doc. No."; Code[20])
        {
            Caption = 'Vendor/Customer Document No.';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51105; "CV Doc. Due Date"; Date)
        {
            Caption = 'Vendor/Customer Document Due Date';
            DataClassification = ToBeClassified;
            Editable = false;
        }
    }
}
