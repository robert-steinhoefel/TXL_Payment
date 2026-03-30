namespace P3.TXL.Payment.Receivables;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Sales.Receivables;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;

pageextension 51102 "CustomerLedgerEntries PageExt" extends "Customer Ledger Entries"
{
    layout
    {
        addafter("Credit Amount")
        {
            field(Paid; Rec.Paid)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Paid field.', Comment = '%';
                Visible = false;
            }
            field("Pmt Cancelled"; Rec."Pmt Cancelled")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Payment Cancelled field.', Comment = '%';
                Visible = false;
            }
            field("Bank Posting Date"; Rec."Bank Posting Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Posting Date field.', Comment = '%';
                Visible = false;
            }
            field("Bank Document No."; Rec."Bank Document No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Document No. field.', Comment = '%';
                Visible = false;
            }
        }
    }
#if TEST
    var
        PostingDescription: Text;

    trigger OnAfterGetRecord()
    var
        SalesInvoice: Record "Sales Invoice Header";
        SalesCrMemo: Record "Sales Cr.Memo Header";
    begin
        case Rec."Document Type" of
            "Gen. Journal Document Type"::Invoice:
                begin
                    if SalesInvoice.Get(Rec."Document No.") then
                        PostingDescription := SalesInvoice."Posting Description"
                    else
                        PostingDescription := Rec."External Document No.";
                end;
            "Gen. Journal Document Type"::Payment:
                PostingDescription := Rec."External Document No.";
            "Gen. Journal Document Type"::"Credit Memo":
                begin
                    if SalesCrMemo.Get(Rec."Document No.") then
                        PostingDescription := SalesCrMemo."Posting Description"
                    else
                        PostingDescription := Rec."External Document No.";
                end;
            "Gen. Journal Document Type"::Refund:
                PostingDescription := Rec."External Document No.";
        end;
    end;

    trigger OnOpenPage()
    begin
        Rec.SetCurrentKey("Entry No.");
        Rec.Ascending(false);
    end;

#endif

}
