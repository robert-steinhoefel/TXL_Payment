codeunit 51000 "Event Subscriber"
{
    [EventSubscriber(ObjectType::Table, Database::"Detailed Vendor Ledg. Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDetailedVendorLedgerEntry(var Rec: Record "Detailed Vendor Ledg. Entry"; RunTrigger: Boolean)
    var
    begin
        if not RunTrigger then
            Message('Attention! Insert has taken place without run trigger!');
        Codeunit.Run(Codeunit::"Vendor Ledger Entries");
        // exit;
    end;
}
