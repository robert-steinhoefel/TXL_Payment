namespace P3.TXL.Payment.Payables;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Purchases.Payables;
using Microsoft.Purchases.History;

pageextension 51101 "VendorLedgerEntries PageExt" extends "Vendor Ledger Entries"
{
    layout
    {
        addafter("Credit Amount")
        {
            field(Paid; Rec.Paid)
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Paid field.', Comment = '%';
                Visible = true;
            }
            field("Pmt Cancelled"; Rec."Pmt Cancelled")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Payment Cancelled field.', Comment = '%';
                Visible = true;
            }
            field("Bank Posting Date"; Rec."Bank Posting Date")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Posting Date field.', Comment = '%';
                Visible = true;
            }
            field("Bank Document No."; Rec."Bank Document No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the value of the Bank Document No. field.', Comment = '%';
                Visible = true;
            }
        }
    }
#if TEST
    var
        PostingDescription: Text;

    trigger OnAfterGetRecord()
    var
        PurchaseInvoice: Record "Purch. Inv. Header";
        PurchaseCrMemo: Record "Purch. Cr. Memo Hdr.";
    begin
        case Rec."Document Type" of
            "Gen. Journal Document Type"::Invoice:
                begin
                    if PurchaseInvoice.Get(Rec."Document No.") then
                        PostingDescription := PurchaseInvoice."Posting Description"
                    else
                        PostingDescription := Rec."External Document No.";
                end;
            "Gen. Journal Document Type"::Payment:
                PostingDescription := Rec."External Document No.";
            "Gen. Journal Document Type"::"Credit Memo":
                begin
                    if PurchaseCrMemo.Get(Rec."Document No.") then
                        PostingDescription := PurchaseCrMemo."Posting Description"
                    else
                        PostingDescription := Rec."External Document No.";
                end;
            "Gen. Journal Document Type"::Refund:
                PostingDescription := Rec."External Document No.";
        end;
    end;
#endif
}
