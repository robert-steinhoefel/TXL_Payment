namespace P3.TXL.Payment.System;
using System.Upgrade;
using Microsoft.Bank.Ledger;

codeunit 51101 "Update Codeunit"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin

    end;
}
