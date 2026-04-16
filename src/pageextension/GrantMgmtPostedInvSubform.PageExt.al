namespace P3.TXL.Payment.Settlement;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Sales.History;

// Story 8.1: Extend the Grant Management "Call for Funds" posted invoice line list (page 50211)
// with payment information from Settlement Entry.
// Source table is Sales Invoice Line — the same table already extended by SalesInvoiceLine.TableExt.al,
// so Settled Amt, Latest Settlement Date, and Latest Bank Doc. No. are all available directly on Rec.
pageextension 51112 "Grant Mgmt Posted Inv. Subform" extends PostedSalesInvSubformViewPage
{
    layout
    {
        addafter("Amount Including VAT")
        {
            field("Settled Amt (LCY)"; Rec."Settled Amt (LCY)")
            {
                ApplicationArea = All;
                Caption = 'Settled Amount';
                ToolTip = 'Specifies the total net settled amount (excl. VAT) for this invoice line across all payments.';
                Editable = false;
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
                ToolTip = 'Specifies the bank statement document number of the most recent settlement. Cleared if all settlements for this line have been reversed.';
                Editable = false;
            }
            field(PaymentStatus; PaymentStatusTxt)
            {
                ApplicationArea = All;
                Caption = 'Payment Status';
                ToolTip = 'Specifies the payment status of this invoice line: Open (no payments), Partial (partly paid), or Paid (fully settled).';
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
