namespace P3.TXL.Payment.Customer;

using Microsoft.Sales.Receivables;

pageextension 51104 "CustLedgEntriesPreview PageExt" extends "Cust. Ledg. Entries Preview"
{
    layout
    {
        addlast(Control1)
        {
            field("Bank Posting Date"; Rec."Bank Posting Date")
            {
                ApplicationArea = All;
                Visible = true;
            }
            field("Bank Document No."; Rec."Bank Document No.")
            {
                ApplicationArea = All;
                Visible = true;
            }
        }
    }
}
