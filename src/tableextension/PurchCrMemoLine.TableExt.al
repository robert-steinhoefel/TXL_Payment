namespace P3.TXL.Payment.Settlement;

using Microsoft.Purchases.History;

tableextension 51109 "PurchCrMemoLine TableExt" extends "Purch. Cr. Memo Line"
{
    fields
    {
        // Story 1.4 / Story 5.4 (Purchase): Link fields for Credit Memo Intelligent Matching.
        // Mirrors the sales-side fields on "Sales Cr.Memo Line".
        // Populated by the credit memo matching logic (Epic 5) to link each purchase credit memo
        // line to the original purchase invoice line it offsets.
        field(51100; "Applied to Invoice No."; Code[20])
        {
            Caption = 'Applied to Invoice No.';
            TableRelation = "Purch. Inv. Header"."No.";
            Editable = false;
        }
        field(51101; "Applied to Invoice Line No."; Integer)
        {
            Caption = 'Applied to Invoice Line No.';
            Editable = false;
        }

        // Story 1.4: Settled Amount (LCY)
        // FlowField: sum of all Settlement Entries created for this purchase credit memo line.
        // Purchase credit memo amounts are stored as-is from BC (negative by convention,
        // consistent with the Spike 5.3.1 decision: no sign transformation applied).
        field(51102; "Settled Amt (LCY)"; Decimal)
        {
            Caption = 'Settled Amount (LCY)';
            FieldClass = FlowField;
            CalcFormula = Sum("Settlement Entry"."Settlement Amt (LCY)"
                WHERE("Document Type" = CONST("Credit Memo"),
                      "Transaction Type" = CONST(Purchase),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No.")));
            Editable = false;
            AutoFormatType = 1;
        }
    }
}
