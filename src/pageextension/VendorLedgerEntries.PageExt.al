namespace ALExtensions.ALExtensions;

using Microsoft.Purchases.Payables;

pageextension 51101 "VendorLedgerEntries PageExt" extends "Vendor Ledger Entries"
{
    layout
    {
        addafter("Credit Amount")
        {
            field(Paid; Rec.Paid)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Paid field.', Comment = '%';
            }
            field("Pmt Cancelled"; Rec."Pmt Cancelled")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Payment Cancelled field.', Comment = '%';
            }
            field("Bank Posting Date"; Rec."Bank Posting Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Posting Date field.', Comment = '%';
            }
            field("Bank Document No."; Rec."Bank Document No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Document No. field.', Comment = '%';
            }
        }
    }
}
