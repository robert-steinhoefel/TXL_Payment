namespace ALExtensions.ALExtensions;

using Microsoft.Purchases.Payables;
using Microsoft.Purchases.Vendor;

tableextension 51001 "VendorLedgerEntry TableExt" extends "Vendor Ledger Entry"
{
    fields
    {
        field(51000; "Paid"; Boolean)
        {
            Caption = 'Paid';
            DataClassification = ToBeClassified;
            // Editable = false;
        }
        field(51001; "Pmt Cancelled"; Boolean)
        {
            Caption = 'Payment Cancelled';
            DataClassification = ToBeClassified;
            // Editable = false;
        }
        field(51002; "Bank Posting Date"; Date)
        {
            Caption = 'Bank Posting Date';
            DataClassification = ToBeClassified;
            // Editable = false;
        }
        field(51003; "Bank Document No."; Code[20])
        {
            Caption = 'Bank Document No.';
            DataClassification = ToBeClassified;
            // Editable = false;
        }
        field(51004; "Vend./Cust. Doc. No."; Code[20])
        {
            Caption = 'Vendor/Customer Document No.';
            DataClassification = ToBeClassified;
            // Editable = false;
        }
        field(51005; "Vend./Cust. Doc. Due Date"; Date)
        {
            Caption = 'Vendor/Customer Document Due Date';
            DataClassification = ToBeClassified;
            // Editable = false;
        }
    }
}
