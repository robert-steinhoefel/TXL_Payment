namespace ALExtensions.ALExtensions;

using Microsoft.Bank.Ledger;

pageextension 51105 "Bank Account Ledger Entries" extends "Bank Account Ledger Entries"
{
    layout
    {
        addafter("Bal. Account No.")
        {

            field("Vend./Cust. Doc Type"; Rec."Vend./Cust. Doc Type")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Document Type field.', Comment = '%';
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
            field("Transaction No."; Rec."Transaction No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Transaction No. field.', Comment = '%';
            }
        }
    }
}
