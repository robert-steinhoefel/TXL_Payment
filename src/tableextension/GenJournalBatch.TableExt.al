namespace ALExtensions.ALExtensions;

using Microsoft.Finance.GeneralLedger.Journal;

tableextension 51103 "Gen. Journal Batches" extends "Gen. Journal Batch"
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
