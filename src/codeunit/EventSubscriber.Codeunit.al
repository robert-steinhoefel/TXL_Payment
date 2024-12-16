codeunit 51000 "Event Subscriber"
{
    [EventSubscriber(ObjectType::Table, Database::"Detailed Vendor Ledg. Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDetailedVendorLedgerEntry(var Rec: Record "Detailed Vendor Ledg. Entry"; RunTrigger: Boolean)
    var
    begin
        if not RunTrigger then
            exit;
        Codeunit.Run(Codeunit::"Vendor Ledger Entries", Rec);
    end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"VendEntry-Apply Posted Entries", 'OnAfterPostApplyVendLedgEntry', '', false, false)]
    // local procedure OnAfterPostApplyVendLedgEntryEditEntries(GenJournalLine: Record "Gen. Journal Line"; VendorLedgerEntry: Record "Vendor Ledger Entry"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line")
    // begin
    //     Message('Pause!');
    // end;
}
