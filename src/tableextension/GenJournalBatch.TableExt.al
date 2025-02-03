namespace P3.TXL.Payment.GenJnl;

using Microsoft.Finance.GeneralLedger.Journal;

tableextension 51103 "GenJournalBatch TableExt" extends "Gen. Journal Batch"

{
    // TODO: Check if this is really needed. There seems to be no use case when singularily looking at the bank ladger entries.
    // fields
    // {
    //     field(51100; "Cameralistic Journal Batch"; Boolean)
    //     {
    //         Caption = 'Cameralistic Journal Batch';
    //         DataClassification = ToBeClassified;
    //     }
    // }
}
