namespace P3.TXL.Payment.System;
using Microsoft.Purchases.Payables;
using Microsoft.Sales.Receivables;
using P3.TXL.Payment.Vendor;
using P3.TXL.Payment.Customer;

codeunit 51100 "Event Subscriber"
{
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

    [EventSubscriber(ObjectType::Table, Database::"Detailed Cust. Ledg. Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure OnAfterInsertDetailedCustomerLedgerEntry(var Rec: Record "Detailed Cust. Ledg. Entry"; RunTrigger: Boolean)
    var
    begin
        if Rec."Entry Type" <> Microsoft.Finance.ReceivablesPayables."Detailed CV Ledger Entry Type"::Application then
            exit;
        if Rec."Initial Document Type" = Microsoft.Finance.GeneralLedger.Journal."Gen. Journal Document Type"::Payment then
            exit;
        if Rec."Initial Document Type" = Microsoft.Finance.GeneralLedger.Journal."Gen. Journal Document Type"::Refund then
            exit;
        Codeunit.Run(Codeunit::"Customer Ledger Entries", Rec);
    end;


}
