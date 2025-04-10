namespace P3.TXL.Payment.Customer;

using Microsoft.Sales.Receivables;

pageextension 51102 "CustomerLedgerEntries PageExt" extends "Customer Ledger Entries"
{
    layout
    {
        addafter("Credit Amount")
        {
            field(Paid; Rec.Paid)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Paid field.', Comment = '%';
                Visible = true;
            }
            field("Pmt Cancelled"; Rec."Pmt Cancelled")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Payment Cancelled field.', Comment = '%';
                Visible = true;
            }
            field("Bank Posting Date"; Rec."Bank Posting Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Posting Date field.', Comment = '%';
                Visible = true;
            }
            field("Bank Document No."; Rec."Bank Document No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Document No. field.', Comment = '%';
                Visible = true;
            }
        }
    }
}
