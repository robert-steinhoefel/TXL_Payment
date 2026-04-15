namespace P3.TXL.Payment.System;
using System.Integration;

codeunit 51105 Installation
{
    Subtype = Install;
    Permissions = tabledata "Tenant Web Service" = ri;

    trigger OnInstallAppPerCompany()
    begin
        CreateBankAccountLedgerEntriesWebService();
        CreateSettlementEntryAPIWebService();
    end;

    // Publishes the Settlement Entry API page (page 51102) as a Tenant Web Service.
    // API pages are accessible at /api/p3group/txlPayment/v1.0/ automatically after
    // deployment, but registering here also adds the endpoint to the OData service
    // document, enabling discovery via Power BI "Get Data from OData feed".
    local procedure CreateSettlementEntryAPIWebService()
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        TenantWebService.SetRange("Object Type", TenantWebService."Object Type"::Page);
        TenantWebService.SetRange("Object ID", 51102);
        if TenantWebService.FindFirst() then
            exit;
        TenantWebService.Init();
        TenantWebService."Object Type" := TenantWebService."Object Type"::Page;
        TenantWebService."Object ID" := 51102;
        TenantWebService."Service Name" := 'SettlementEntries';
        TenantWebService.Published := true;
        TenantWebService.Insert();
    end;

    [Obsolete('Obsolete with settlement entries per line.', '25.3.1.6')]
    local procedure CreateBankAccountLedgerEntriesWebService()
    var
        TenantWebService: Record "Tenant Web Service";
    begin
        TenantWebService.SetRange("Object Type", TenantWebService."Object Type"::Query);
        TenantWebService.SetRange("Object ID", 51100);
        TenantWebService.SetFilter("Service Name", 'CameralisticBankAccountLedgerEntries');
        if TenantWebService.FindFirst() then
            exit
        else begin
            TenantWebService.Init();
            TenantWebService."Object Type" := TenantWebService."Object Type"::Query;
            TenantWebService."Object ID" := 51100;
            TenantWebService."Service Name" := 'CameralisticBankAccountLedgerEntries';
            TenantWebService.Published := true;
            TenantWebService.Insert();
        end;
    end;
}
