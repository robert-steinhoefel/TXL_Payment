namespace P3.TXL.Payment.GenJnl;

using Microsoft.Finance.GeneralLedger.Journal;

pageextension 51104 "GeneralJournalBatches PageExt" extends "General Journal Batches"
{
    layout
    {
        addafter("Reason Code")
        {
            field("Cameralistic Journal Batch"; Rec."Cameralistic Journal Batch")
            {
                ApplicationArea = All;
                Caption = 'Cameralistic Journal Batch';
            }
        }
    }
}
