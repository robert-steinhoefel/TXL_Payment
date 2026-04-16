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

        // Story 8.2: Outstanding Amount (LCY)
        // Stored decimal maintained by SettlementEntryMgt after every purchase credit memo
        // settlement entry insert or reversal — mirrors the same field on Purch. Inv. Line.
        // Will show 0 until Epic 9 adds purchase credit memo settlement creation.
        field(51103; "Outstanding Amt (LCY)"; Decimal)
        {
            Caption = 'Outstanding Amount (LCY)';
            DataClassification = CustomerContent;
            Editable = false;
            AutoFormatType = 1;
        }

        // Story 8.2: Latest Settlement Date — most recent non-reversal settlement date for this purchase CM line.
        field(51104; "Latest Settlement Date"; Date)
        {
            Caption = 'Latest Settlement Date';
            FieldClass = FlowField;
            CalcFormula = Max("Settlement Entry"."Settlement Date"
                WHERE("Document Type" = CONST("Credit Memo"),
                      "Transaction Type" = CONST(Purchase),
                      "Document No." = FIELD("Document No."),
                      "Document Line No." = FIELD("Line No."),
                      "Reversal Entry" = CONST(false)));
            Editable = false;
        }

        // Story 8.2: Latest Bank Document No. — stored, maintained by SettlementEntryMgt.
        // Will remain blank until Epic 9 adds purchase credit memo settlement creation.
        field(51105; "Latest Bank Doc. No."; Code[20])
        {
            Caption = 'Latest Bank Doc. No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
