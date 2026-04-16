namespace P3.TXL.Payment.Payables;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Purchases.History;
using P3.TXL.Payment.Settlement;

// Story 8.2: Extend the Posted Purchase Credit Memo header (page 170) with document-level
// payment summary fields: total settled amount, latest payment date, and payment status.
// Calculated via PaymentInfoCalculator on page load — no table extension needed.
// All fields are hidden (Visible = false) until Epic 9 adds purchase credit memo settlement creation.
pageextension 51116 "PostedPurchCrMemo PageExt" extends "Posted Purchase Credit Memo"
{
    layout
    {
        addlast(General)
        {
            group(PaymentSummary)
            {
                Caption = 'Payment Summary';
                Visible = false;

                field(DocTotalSettled; DocTotalSettledAmt)
                {
                    ApplicationArea = All;
                    Caption = 'Total Settled Amount';
                    ToolTip = 'Specifies the net total amount settled across all lines of this purchase credit memo (LCY).';
                    Editable = false;
                    AutoFormatType = 1;
                    DrillDown = true;

                    trigger OnDrillDown()
                    var
                        SettlementEntry: Record "Settlement Entry";
                        SettlementEntryList: Page "Settlement Entry List";
                    begin
                        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::"Credit Memo");
                        SettlementEntry.SetRange("Transaction Type", "Settlement Transaction Type"::Purchase);
                        SettlementEntry.SetRange("Document No.", Rec."No.");
                        SettlementEntryList.SetTableView(SettlementEntry);
                        SettlementEntryList.Run();
                    end;
                }
                field(DocLatestSettlementDate; DocLatestSettlementDate)
                {
                    ApplicationArea = All;
                    Caption = 'Latest Payment Date';
                    ToolTip = 'Specifies the date of the most recent settlement for this purchase credit memo.';
                    Editable = false;
                }
                field(DocPaymentStatus; DocPaymentStatusTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Payment Status';
                    ToolTip = 'Specifies the overall payment status of this purchase credit memo: Open, Partial, or Paid.';
                    Editable = false;
                    StyleExpr = DocPaymentStatusStyle;
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    var
        Calculator: Codeunit "Payment Info Calculator";
        Status: Enum "Settlement Payment Status";
    begin
        DocTotalSettledAmt := Calculator.GetDocumentTotalSettled(Rec."No.", "Gen. Journal Document Type"::"Credit Memo", "Settlement Transaction Type"::Purchase);
        DocLatestSettlementDate := Calculator.GetDocumentLatestSettlementDate(Rec."No.", "Gen. Journal Document Type"::"Credit Memo", "Settlement Transaction Type"::Purchase);
        Status := Calculator.GetDocumentPaymentStatus(Rec."No.", "Gen. Journal Document Type"::"Credit Memo", "Settlement Transaction Type"::Purchase);
        DocPaymentStatusTxt := Format(Status);
        DocPaymentStatusStyle := Calculator.GetPaymentStatusStyle(Status);
    end;

    var
        DocTotalSettledAmt: Decimal;
        DocLatestSettlementDate: Date;
        DocPaymentStatusTxt: Text;
        DocPaymentStatusStyle: Text;
}
