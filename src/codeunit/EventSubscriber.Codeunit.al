namespace RST.TXL_Payment;
using Microsoft.Purchases.Payables;

codeunit 51100 "Event Subscriber"
{
    // [EventSubscriber(ObjectType::Table, Database::"Detailed Vendor Ledg. Entry", 'OnAfterModifyEvent', '', false, false)]
    // local procedure OnAfterModifyDetailedVendorLedgerEntry(var Rec: Record "Detailed Vendor Ledg. Entry"; var xRec: Record "Detailed Vendor Ledg. Entry"; RunTrigger: Boolean)
    // var
    // begin
    //     if Rec.IsTemporary then
    //         exit;
    //     Message('Rec:\' + Format(Rec) + '\xRec:\' + Format(xRec));
    // end;
    [EventSubscriber(ObjectType::Table, Database::"Detailed Vendor Ledg. Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDetailedVendorLedgerEntry(var Rec: Record "Detailed Vendor Ledg. Entry"; RunTrigger: Boolean)
    var
    begin
        if Rec."Entry Type" <> Microsoft.Finance.ReceivablesPayables."Detailed CV Ledger Entry Type"::Application then
            exit;
        if Rec."Initial Document Type" = Microsoft.Finance.GeneralLedger.Journal."Gen. Journal Document Type"::Payment then
            exit;
        if Rec."Initial Document Type" = Microsoft.Finance.GeneralLedger.Journal."Gen. Journal Document Type"::Refund then
            exit;
        Codeunit.Run(Codeunit::"Vendor Ledger Entries", Rec);
    end;

    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"VendEntry-Apply Posted Entries", 'OnVendPostApplyVendLedgEntryOnBeforeCommit', '', false, false)]
    // // [EventSubscriber(ObjectType::Codeunit, Codeunit::"VendEntry-Apply Posted Entries", 'OnAfterPostApplyVendLedgEntry', '', false, false)]
    // // local procedure OnAfterSetApplicationIdDtlVendorLedgerEntry(var VendLedgerEntry: Record "Vendor Ledger Entry")
    // local procedure OnAfterPostApplyVendorLedgerEntry(VendLedgerEntry: Record "Vendor Ledger Entry")
    // begin
    //     // Message('halt');
    //     // Codeunit.Run(Codeunit::"Vendor Ledger Entries", VendLedgerEntry);
    // end;

    // // [EventSubscriber(ObjectType::Codeunit, Codeunit::"VendEntry-Apply Posted Entries", 'OnVendPostApplyVendLedgEntryOnBeforeCommit', '', false, false)]
    // [EventSubscriber(ObjectType::Codeunit, Codeunit::"VendEntry-Apply Posted Entries", 'OnAfterPostUnApplyVendLedgEntry', '', false, false)]
    // // local procedure OnAfterSetApplicationIdDtlVendorLedgerEntry(var VendLedgerEntry: Record "Vendor Ledger Entry")
    // local procedure OnAfterPostUnApplyVendorLedgerEntry(VendorLedgerEntry: Record "Vendor Ledger Entry")
    // begin
    //     // Codeunit.Run(Codeunit::"Vendor Ledger Entries", VendorLedgerEntry);
    // end;
}
