namespace P3.TXL.Payment.Payables;

using Microsoft.Purchases.History;

// Story 1.4: Extend Posted Purch. Invoice Subform with Settlement FlowFields.
// Purchase-side mirror of PostedSalesInvoiceSubform.PageExt.al.
// Shows the net settled and outstanding amounts per purchase invoice line, sourced from
// Settlement Entry (table 51106) via FlowFields defined on Purch. Inv. Line (TableExt 51108).
// BC automatically calculates FlowFields when the page record is fetched — no OnAfterGetRecord trigger needed.
pageextension 51106 "Posted Purch. Invoice Subform" extends "Posted Purch. Invoice Subform"
{
    layout
    {
        addafter("Total Amount Incl. VAT")
        {
            // FlowField: summed from Settlement Entry where Document Type = Invoice, Transaction Type = Purchase.
            // Includes reversal entries (opposite signs), so the result is always the net settled amount.
            field("Settled Amt (LCY)"; Rec."Settled Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the total amount settled for this purchase invoice line (LCY).';
                Visible = true;
            }

            // Stored Decimal maintained by SettlementEntryMgt (Epic 2/3).
            // Cannot be a FlowField: BC CalcFormulas do not support arithmetic between Sum() expressions
            // across tables, so (Amount - Settled Amount) cannot be expressed as a CalcFormula.
            field("Outstanding Amt (LCY)"; Rec."Outstanding Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the remaining unpaid amount for this purchase invoice line (LCY).';
                Visible = true;
            }
        }
    }
}
