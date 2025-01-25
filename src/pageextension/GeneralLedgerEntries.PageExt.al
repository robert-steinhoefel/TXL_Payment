namespace ALExtensions.ALExtensions;

using Microsoft.Finance.GeneralLedger.Ledger;

pageextension 51100 "GeneralLedgerEntries PageExt" extends "General Ledger Entries"
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
            field("Vend./Cust. Doc. Due Date"; Rec."Vend./Cust. Doc. Due Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Document Due Date field.', Comment = '%';
            }
            field("Vend./Cust. Doc. No."; Rec."Vend./Cust. Doc. No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Document No. field.', Comment = '%';
            }
        }
    }
}
