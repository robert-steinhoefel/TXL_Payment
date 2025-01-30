namespace P3.TXL.Payment.GenJnl;

using Microsoft.Finance.GeneralLedger.Journal;

tableextension 51103 "GenJournalBatch TableExt" extends "Gen. Journal Batch"
{
    fields
    {
        field(51100; "Cameralistic Journal Batch"; Boolean)
        {
            Caption = 'Cameralistic Journal Batch';
            DataClassification = ToBeClassified;
        }
    }
}
