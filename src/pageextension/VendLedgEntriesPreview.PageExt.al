namespace P3.TXL.Payment.Vendor;

using Microsoft.Purchases.Payables;

pageextension 51105 "VendLedgEntriesPreview PageExt" extends "Vend. Ledg. Entries Preview"
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
