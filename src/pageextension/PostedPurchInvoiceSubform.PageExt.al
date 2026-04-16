namespace P3.TXL.Payment.Payables;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Purchases.History;
using P3.TXL.Payment.Settlement;

// Story 1.4: Settled Amt + Outstanding Amt on Posted Purch. Invoice Subform.
// Story 8.2: Extended with Latest Settlement Date, Latest Bank Doc. No.,
//            Payment Status (colour-coded), and DrillDown to Settlement Entry List.
//            Fields will show blank/zero until Epic 9 adds purchase settlement creation.
pageextension 51106 "Posted Purch. Invoice Subform" extends "Posted Purch. Invoice Subform"
{
    layout
    {
        addafter("Total Amount Incl. VAT")
        {
            field("Settled Amt (LCY)"; Rec."Settled Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the total amount settled for this purchase invoice line (LCY).';
                Visible = true;
                DrillDown = true;

                trigger OnDrillDown()
                var
                    SettlementEntry: Record "Settlement Entry";
                    SettlementEntryList: Page "Settlement Entry List";
                begin
                    SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
                    SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Purchase);
                    SettlementEntry.SetRange("Document No.", Rec."Document No.");
                    SettlementEntry.SetRange("Document Line No.", Rec."Line No.");
                    SettlementEntryList.SetTableView(SettlementEntry);
                    SettlementEntryList.Run();
                end;
            }
            field("Outstanding Amt (LCY)"; Rec."Outstanding Amt (LCY)")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the remaining unpaid amount for this purchase invoice line (LCY).';
                Visible = true;
            }
            field("Latest Settlement Date"; Rec."Latest Settlement Date")
            {
                ApplicationArea = All;
                Caption = 'Latest Payment Date';
                ToolTip = 'Specifies the date of the most recent payment settlement for this purchase invoice line.';
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
                ToolTip = 'Specifies the payment status of this purchase invoice line: Open, Partial, or Paid.';
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
