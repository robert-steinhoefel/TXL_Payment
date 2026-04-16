namespace P3.TXL.Payment.Receivables;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Sales.History;
using P3.TXL.Payment.Settlement;

// Story 1.4: Settled Amt + Outstanding Amt on Posted Sales Invoice Subform.
// Story 8.2: Extended with Latest Settlement Date, Latest Bank Doc. No.,
//            Payment Status (colour-coded), and DrillDown to Settlement Entry List.
pageextension 51104 "Posted Sales Invoice Subform" extends "Posted Sales Invoice Subform"
{
    layout
    {
        addafter("Total Amount Incl. VAT")
        {
            field("Settled Amt (LCY)"; Rec."Settled Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the total amount settled for this invoice line (LCY).';
                Visible = true;
                DrillDown = true;

                trigger OnDrillDown()
                var
                    SettlementEntry: Record "Settlement Entry";
                    SettlementEntryList: Page "Settlement Entry List";
                begin
                    SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
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
                ToolTip = 'Specifies the remaining unpaid amount for this invoice line (LCY).';
                Visible = true;
            }
            field("Latest Settlement Date"; Rec."Latest Settlement Date")
            {
                ApplicationArea = All;
                Caption = 'Latest Payment Date';
                ToolTip = 'Specifies the date of the most recent payment settlement for this invoice line.';
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
                ToolTip = 'Specifies the payment status of this invoice line: Open, Partial, or Paid.';
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
