namespace P3.TXL.Payment.Settlement;

using Microsoft.Sales.History;

tableextension 51107 "SalesCrMemoLine TableExt" extends "Sales Cr.Memo Line"
{
    fields
    {
        // Story 1.4 / Story 5.4: Link fields for Credit Memo Intelligent Matching (3-Tier Algorithm).
        // Populated by the credit memo matching logic (Epic 5 / Story 5.4) to link each credit
        // memo line to the invoice line it offsets, enabling net amount calculation per line.
        field(51100; "Applied to Invoice No."; Code[20])
        {
            Caption = 'Applied to Invoice No.';
            TableRelation = "Sales Invoice Header"."No.";
            Editable = false;
        }
        field(51101; "Applied to Invoice Line No."; Integer)
        {
            Caption = 'Applied to Invoice Line No.';
            Editable = false;
        }

        // Story 1.4: Settled Amount (LCY)
        // FlowField: sum of all Settlement Entries created for this credit memo line.
        // Credit memo settlement entries carry negative amounts by convention (Spike 5.3.1 decision:
        // amounts are stored as they come from the source table — credit memo amounts are negative in BC).
        field(51102; "Settled Amt (LCY)"; Decimal)
        {
            Caption = 'Settled Amount (LCY)';
            FieldClass = FlowField;
            CalcFormula = Sum("Settlement Entry"."Settlement Amt (LCY)"
                WHERE("Document Type" = CONST("Credit Memo"),
                      "Transaction Type" = CONST(Sales),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No.")));
            Editable = false;
            AutoFormatType = 1;
        }
    }
}
