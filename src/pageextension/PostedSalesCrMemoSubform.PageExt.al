namespace P3.TXL.Payment.Receivables;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Sales.History;
using P3.TXL.Payment.Settlement;

// Story 1.4: Extend Posted Sales Cr. Memo Subform with applied-to link fields and Settlement FlowField.
// Story 8.2: Extended with Outstanding Amt, Latest Settlement Date, Latest Bank Doc. No.,
//            Payment Status (colour-coded), and DrillDown to Settlement Entry List.
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
            field("Settled Amt (LCY)"; Rec."Settled Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the total settled amount for this credit memo line (LCY).';
                Visible = true;
                DrillDown = true;

                trigger OnDrillDown()
                var
                    SettlementEntry: Record "Settlement Entry";
                    SettlementEntryList: Page "Settlement Entry List";
                begin
                    SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
                    SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Sales);
                    SettlementEntry.SetRange("Document No.", Rec."Document No.");
                    SettlementEntry.SetRange("Document Line No.", Rec."Line No.");
                    SettlementEntryList.SetTableView(SettlementEntry);
                    SettlementEntryList.Run();
                end;
            }
            field("Outstanding Amt (LCY)"; Rec."Outstanding Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the remaining unapplied amount for this credit memo line (LCY).';
                Visible = true;
            }
            field("Latest Settlement Date"; Rec."Latest Settlement Date")
            {
                ApplicationArea = All;
                Caption = 'Latest Payment Date';
                ToolTip = 'Specifies the date of the most recent settlement for this credit memo line.';
                Editable = false;
            }
            field("Latest Bank Doc. No."; Rec."Latest Bank Doc. No.")
            {
                ApplicationArea = All;
                Caption = 'Latest Bank Doc. No.';
                ToolTip = 'Specifies the bank statement document number of the most recent settlement.';
                Editable = false;
            }
            field(PaymentStatus; PaymentStatusTxt)
            {
                ApplicationArea = All;
                Caption = 'Payment Status';
                ToolTip = 'Specifies the payment status of this credit memo line: Open, Partial, or Paid.';
                Editable = false;
                StyleExpr = PaymentStatusStyle;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Calculator: Codeunit "Payment Info Calculator";
        Status: Enum "Settlement Payment Status";
    begin
        Rec.CalcFields("Settled Amt (LCY)", "Latest Settlement Date");
        Status := Calculator.GetPaymentStatus(Rec);
        PaymentStatusTxt := Format(Status);
        PaymentStatusStyle := Calculator.GetPaymentStatusStyle(Status);
    end;

    var
        PaymentStatusTxt: Text;
        PaymentStatusStyle: Text;
}
