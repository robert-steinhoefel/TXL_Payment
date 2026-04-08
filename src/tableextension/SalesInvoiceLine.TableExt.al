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
            // Sums "Total Settled Amt (LCY)" = Settlement Amt + Cash Discount Amt (both excl. VAT).
            // BC CalcFormula cannot sum two fields in one expression, so SettlementEntryMgt
            // maintains that combined field. Includes cash discount so that a discount-closed
            // invoice correctly shows Outstanding Amt = 0.
            CalcFormula = Sum("Settlement Entry"."Total Settled Amt (LCY)"
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

        field(51102; "Settled Amt Incl. VAT (LCY)"; Decimal)
        {
            Caption = 'Settled Amount Incl. VAT (LCY)';
            FieldClass = FlowField;
            // Sums "Total Settled Amt Incl. VAT (LCY)" which = Settlement Amt Incl. VAT +
            // Cash Discount Amt Incl. VAT per entry. BC CalcFormula cannot sum two fields
            // in one expression, so SettlementEntryMgt maintains that combined field.
            CalcFormula = Sum("Settlement Entry"."Total Settled Amt Incl. VAT (LCY)"
                WHERE("Document Type" = CONST(Invoice),
                      "Transaction Type" = CONST(Sales),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No.")));
            Editable = false;
            AutoFormatType = 1;
        }
    }
}
