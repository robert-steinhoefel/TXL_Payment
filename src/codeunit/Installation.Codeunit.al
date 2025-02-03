namespace P3.TXL.Payment.System;
using System.Integration;

codeunit 51105 Installation
{
    Subtype = Install;
    Permissions = tabledata "Tenant Web Service" = i;

    trigger OnInstallAppPerCompany()
    begin
        CreateBankAccountLedgerEntriesWebService();
    end;

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
