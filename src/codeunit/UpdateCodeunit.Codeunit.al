namespace P3.TXL.Payment.System;
using System.Upgrade;

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
