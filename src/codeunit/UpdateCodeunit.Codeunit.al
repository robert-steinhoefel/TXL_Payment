namespace P3.TXL.Payment.System;
using Microsoft.Finance.GeneralLedger.Ledger;
using System.Upgrade;
using Microsoft.Sales.Receivables;
using Microsoft.Purchases.Payables;

codeunit 51101 "Update Codeunit"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        // if not UpgradeTag.HasUpgradeTag('') then
        // begin

        // end;
    end;
}
