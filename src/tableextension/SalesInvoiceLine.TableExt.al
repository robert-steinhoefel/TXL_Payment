namespace P3.TXL.Payment.Settlement;

using Microsoft.Sales.History;

tableextension 51106 "SalesInvoiceLine TableExt" extends "Sales Invoice Line"
{
    fields
    {
        // Story 1.4: Settled Amount (LCY)
        // FlowField: sum of all Settlement Entries for this invoice line.
        // Includes reversals (which carry opposite signs), so the result is always the net settled amount.
        // Call CalcFields("Settled Amount (LCY)") before using this field.
        field(51100; "Settled Amt (LCY)"; Decimal)
        {
            Caption = 'Settled Amount (LCY)';
            FieldClass = FlowField;
            CalcFormula = Sum("Settlement Entry"."Settlement Amt (LCY)"
                WHERE("Document Type" = CONST(Invoice),
                      "Transaction Type" = CONST(Sales),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No.")));
            Editable = false;
            AutoFormatType = 1;
        }

        // Story 1.4: Outstanding Amount (LCY)
        // BC CalcFormulas do not support arithmetic between two Sum() expressions across tables,
        // so this cannot be a FlowField of the form (Line Amount - Settled Amount).
        // This field is maintained by SettlementEntryMgt (Epic 2/3):
        //   - Set to Line Amount on first settlement creation.
        //   - Decremented on each further settlement.
        //   - Incremented on reversal.
        // On pages, you can also compute it inline as:  Rec.Amount - Rec."Settled Amount (LCY)"
        // after CalcFields("Settled Amount (LCY)").
        field(51101; "Outstanding Amt (LCY)"; Decimal)
        {
            Caption = 'Outstanding Amount (LCY)';
            DataClassification = CustomerContent;
            Editable = false;
            AutoFormatType = 1;
        }
    }
}
