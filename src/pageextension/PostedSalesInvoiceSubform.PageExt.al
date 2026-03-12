namespace P3.TXL.Payment.Receivables;

using Microsoft.Sales.History;

// Story 1.4: Extend Posted Sales Invoice Subform with Settlement FlowFields.
// Shows the net settled and outstanding amounts per invoice line, sourced from
// Settlement Entry (table 51106) via FlowFields defined on Sales Invoice Line (TableExt 51106).
// BC automatically calculates FlowFields when the page record is fetched — no OnAfterGetRecord trigger needed.
pageextension 51104 "Posted Sales Invoice Subform" extends "Posted Sales Invoice Subform"
{
    layout
    {
        addafter("Total Amount Incl. VAT")
        {
            // FlowField: summed from Settlement Entry where Document Type = Invoice, Transaction Type = Sales.
            // Includes reversal entries (opposite signs), so the result is always the net settled amount.
            field("Settled Amt (LCY)"; Rec."Settled Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the total amount settled for this invoice line (LCY).';
                Visible = true;
            }

            // Stored Decimal maintained by SettlementEntryMgt (Epic 2/3).
            // Cannot be a FlowField: BC CalcFormulas do not support arithmetic between Sum() expressions
            // across tables, so (Amount - Settled Amount) cannot be expressed as a CalcFormula.
            field("Outstanding Amt (LCY)"; Rec."Outstanding Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the remaining unpaid amount for this invoice line (LCY).';
                Visible = true;
            }
        }
    }
}
