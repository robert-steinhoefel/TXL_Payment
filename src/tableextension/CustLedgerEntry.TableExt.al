namespace P3.TXL.Payment.Customer;

using Microsoft.Sales.Receivables;

tableextension 51102 "CustLedgerEntry TableExt" extends "Cust. Ledger Entry"
{
    fields
    {
        field(51100; "Paid"; Boolean)
        {
            ObsoleteState = Pending;
            ObsoleteReason = 'Obsolete with settlement entries per line.';
            ObsoleteTag = '25.3.1.6';
            Caption = 'Paid';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51101; "Pmt Cancelled"; Boolean)
        {
            ObsoleteState = Pending;
            ObsoleteReason = 'Obsolete with settlement entries per line.';
            ObsoleteTag = '25.3.1.6';
            Caption = 'Payment Cancelled';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51102; "Bank Posting Date"; Date)
        {
            ObsoleteState = Pending;
            ObsoleteReason = 'Obsolete with settlement entries per line.';
            ObsoleteTag = '25.3.1.6';
            Caption = 'Bank Posting Date';
            DataClassification = ToBeClassified;
            Editable = false;
        }
        field(51103; "Bank Document No."; Code[20])
        {
            ObsoleteState = Pending;
            ObsoleteReason = 'Obsolete with settlement entries per line.';
            ObsoleteTag = '25.3.1.6';
            Caption = 'Bank Document No.';
            DataClassification = ToBeClassified;
            Editable = false;
        }
    }
}
