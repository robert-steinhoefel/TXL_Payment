namespace ALExtensions.ALExtensions;

using Microsoft.Bank.Ledger;

pageextension 51105 "Bank Account Ledger Entries" extends "Bank Account Ledger Entries"
{
    layout
    {
        addafter("Bal. Account No.")
        {

            field("Vend./Cust. Doc Type"; Rec."CV Doc Type")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Document Type field.', Comment = '%';
            }
            field("Vend./Cust. Doc. Due Date"; Rec."CV Doc. Due Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Document Due Date field.', Comment = '%';
            }
            field("Vend./Cust. Doc. No."; Rec."CV Doc. No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Document No. field.', Comment = '%';
            }
            field("Transaction No."; Rec."Transaction No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Transaction No. field.', Comment = '%';
            }
            field("CV Global Dimension 1 Code"; Rec."CV Global Dimension 1 Code")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Global Dimension 1 Code field.', Comment = '%';
            }
            field("CV Global Dimension 2 Code"; Rec."CV Global Dimension 2 Code")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Global Dimension 2 Code field.', Comment = '%';
            }
            field("CV Dimension Set ID"; Rec."CV Dimension Set ID")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Vendor/Customer Dimension Set ID field.', Comment = '%';
            }

        }
    }
}
