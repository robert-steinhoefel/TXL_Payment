namespace P3.TXL.Payment.Receivables;

using Microsoft.Sales.History;

// Story 1.4: Extend Posted Sales Cr. Memo Subform with applied-to link fields and Settlement FlowField.
// The "Applied to" fields link each credit memo line to the specific invoice line it offsets,
// enabling net amount calculation per line. They are populated by the credit memo matching
// logic in Epic 5 / Story 5.4 (Credit Memo Intelligent Matching — 3-Tier Algorithm).
pageextension 51105 "Posted Sales Cr. Memo Subform" extends "Posted Sales Cr. Memo Subform"
{
    layout
    {
        addafter("Total Amount Incl. VAT")
        {
            // Link fields: populated by credit memo matching logic (Epic 5 / Story 5.4).
            field("Applied to Invoice No."; Rec."Applied to Invoice No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the posted sales invoice number that this credit memo line offsets.';
                Visible = true;
            }
            field("Applied to Invoice Line No."; Rec."Applied to Invoice Line No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the invoice line number that this credit memo line offsets.';
                Visible = true;
            }

            // FlowField: summed from Settlement Entry where Document Type = Credit Memo, Transaction Type = Sales.
            // Credit memo entries carry negative amounts by convention (Spike 5.3.1 decision: amounts stored as-is).
            field("Settled Amt (LCY)"; Rec."Settled Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the total settled amount for this credit memo line (LCY).';
                Visible = true;
            }
        }
    }
}
