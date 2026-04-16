namespace P3.TXL.Payment.Settlement;

using Microsoft.Purchases.History;

tableextension 51108 "PurchInvLine TableExt" extends "Purch. Inv. Line"
{
    fields
    {
        // Story 1.4: Settled Amount (LCY)
        // FlowField: sum of all Settlement Entries for this purchase invoice line.
        // Includes reversals (which carry opposite signs), so the result is always the net settled amount.
        // Call CalcFields("Settled Amount (LCY)") before using this field.
        field(51100; "Settled Amt (LCY)"; Decimal)
        {
            Caption = 'Settled Amount (LCY)';
            FieldClass = FlowField;
            CalcFormula = Sum("Settlement Entry"."Settlement Amt (LCY)"
                WHERE("Document Type" = CONST(Invoice),
                      "Transaction Type" = CONST(Purchase),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No.")));
            Editable = false;
            AutoFormatType = 1;
        }

        // Story 1.4: Outstanding Amount (LCY)
        // See SalesInvoiceLine.TableExt.al for the rationale on why this is not a FlowField.
        // Maintained by SettlementEntryMgt (Epic 2/3).
        field(51101; "Outstanding Amt (LCY)"; Decimal)
        {
            Caption = 'Outstanding Amount (LCY)';
            DataClassification = CustomerContent;
            Editable = false;
            AutoFormatType = 1;
        }

        // Story 8.2: Latest Settlement Date (Purchase mirror of SalesInvoiceLine field 51103).
        // Excludes reversal entries so the date reflects the last genuine payment.
        // Will remain blank until Epic 9 adds purchase settlement creation.
        field(51103; "Latest Settlement Date"; Date)
        {
            Caption = 'Latest Settlement Date';
            FieldClass = FlowField;
            CalcFormula = Max("Settlement Entry"."Settlement Date"
                WHERE("Document Type" = CONST(Invoice),
                      "Transaction Type" = CONST(Purchase),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No."),
                      "Reversal Entry" = CONST(false)));
            Editable = false;
        }

        // Story 8.2: Latest Bank Document No. (Purchase mirror of SalesInvoiceLine field 51104).
        // Stored field maintained by SettlementEntryMgt purchase path (Epic 9).
        // Will remain blank until Epic 9 adds purchase settlement creation.
        field(51104; "Latest Bank Doc. No."; Code[20])
        {
            Caption = 'Latest Bank Doc. No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
