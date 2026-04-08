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
        // FlowField: sum of Total Settled Amt (LCY) for all Settlement Entries for this line.
        // Uses Total Settled Amt (same as Sales Invoice Line) so that cash discounts are
        // included — Outstanding Amt = Amount - Settled Amt reaches 0 when the credit memo
        // is fully applied even when a payment discount was granted.
        // SalesCrMemoLine.Amount is positive in BC (the credit granted to the customer).
        field(51102; "Settled Amt (LCY)"; Decimal)
        {
            Caption = 'Settled Amount (LCY)';
            FieldClass = FlowField;
            CalcFormula = Sum("Settlement Entry"."Total Settled Amt (LCY)"
                WHERE("Document Type" = CONST("Credit Memo"),
                      "Transaction Type" = CONST(Sales),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No.")));
            Editable = false;
            AutoFormatType = 1;
        }

        // Story 5.3: Outstanding Amount (LCY)
        // Stored decimal maintained by SettlementEntryMgt after every credit memo settlement
        // entry insert or reversal — mirrors the same field on Sales Invoice Line.
        // Formula: Amount - Settled Amt (LCY). SalesCrMemoLine.Amount is positive (the credit
        // granted to the customer), so Outstanding starts at Amount and decreases toward 0 as
        // the credit memo is applied. Fully settled = Outstanding <= 0.
        // Cannot be a FlowField: BC CalcFormulas do not support arithmetic between Sum()
        // expressions across tables (same constraint as Sales Invoice Line).
        field(51103; "Outstanding Amt (LCY)"; Decimal)
        {
            Caption = 'Outstanding Amount (LCY)';
            DataClassification = CustomerContent;
            Editable = false;
            AutoFormatType = 1;
        }
    }
}
