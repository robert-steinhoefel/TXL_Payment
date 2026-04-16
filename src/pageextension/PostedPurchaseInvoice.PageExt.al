namespace P3.TXL.Payment.Payables;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Purchases.History;
using P3.TXL.Payment.Settlement;

// Story 8.2: Extend the Posted Purchase Invoice header (page 136) with document-level
// payment summary fields: total settled amount, latest payment date, and payment status.
// Calculated via PaymentInfoCalculator on page load — no table extension needed.
// Fields will show zero/blank until Epic 9 adds purchase settlement creation.
pageextension 51114 "PostedPurchaseInvoice PageExt" extends "Posted Purchase Invoice"
{
    layout
    {
        addlast(General)
        {
            group(PaymentSummary)
            {
                Caption = 'Payment Summary';

                field(DocTotalSettled; DocTotalSettledAmt)
                {
                    ApplicationArea = All;
                    Caption = 'Total Settled Amount';
                    ToolTip = 'Specifies the net total amount settled across all lines of this purchase invoice (LCY).';
                    Editable = false;
                    AutoFormatType = 1;
                    DrillDown = true;

                    trigger OnDrillDown()
                    var
                        SettlementEntry: Record "Settlement Entry";
                        SettlementEntryList: Page "Settlement Entry List";
                    begin
                        SettlementEntry.SetRange("Document Type", "Gen. Journal Document Type"::Invoice);
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
                    ToolTip = 'Specifies the date of the most recent payment settlement for this purchase invoice.';
                    Editable = false;
                }
                field(DocPaymentStatus; DocPaymentStatusTxt)
                {
                    ApplicationArea = All;
                    Caption = 'Payment Status';
                    ToolTip = 'Specifies the overall payment status of this purchase invoice: Open, Partial, or Paid.';
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
        DocTotalSettledAmt := Calculator.GetDocumentTotalSettled(Rec."No.", "Gen. Journal Document Type"::Invoice, "Settlement Transaction Type"::Purchase);
        DocLatestSettlementDate := Calculator.GetDocumentLatestSettlementDate(Rec."No.", "Gen. Journal Document Type"::Invoice, "Settlement Transaction Type"::Purchase);
        Status := Calculator.GetDocumentPaymentStatus(Rec."No.", "Gen. Journal Document Type"::Invoice, "Settlement Transaction Type"::Purchase);
        DocPaymentStatusTxt := Format(Status);
        DocPaymentStatusStyle := Calculator.GetPaymentStatusStyle(Status);
    end;

    var
        DocTotalSettledAmt: Decimal;
        DocLatestSettlementDate: Date;
        DocPaymentStatusTxt: Text;
        DocPaymentStatusStyle: Text;
}
