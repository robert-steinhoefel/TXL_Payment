#if TEST
namespace TXL.TXL;

using Microsoft.Sales.Receivables;

pageextension 51108 "Detailed Cust. Ledg. Entries" extends "Detailed Cust. Ledg. Entries"
{
    layout
    {
        addafter("Cust. Ledger Entry No.")
        {
            field("Applied Cust. Ledger Entry No."; Rec."Applied Cust. Ledger Entry No.")
            {
                ApplicationArea = All;
                Visible = true;
            }
            field("Transaction No."; Rec."Transaction No.")
            {
                ApplicationArea = All;
                Visible = true;
            }
            field("Initial Document Type"; Rec."Initial Document Type")
            {
                ApplicationArea = All;
                Visible = true;
            }
        }
        addlast(Control1)
        {
            field(SystemCreatedAt; Rec.SystemCreatedAt)
            {
                ApplicationArea = All;
                Visible = true;
            }
        }
    }
}
#endif