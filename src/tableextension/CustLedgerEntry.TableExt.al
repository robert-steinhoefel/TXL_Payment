namespace P3.TXL.Payment.Customer;

using Microsoft.Sales.Receivables;

tableextension 51102 "CustLedgerEntry TableExt" extends "Cust. Ledger Entry"
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
    }
}
