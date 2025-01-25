namespace ALExtensions.ALExtensions;
using Microsoft.Finance.GeneralLedger.Ledger;
using System.Upgrade;
using Microsoft.Sales.Receivables;
using Microsoft.Purchases.Payables;

codeunit 51101 "Update Codeunit"
{
    Subtype = Upgrade;
    Permissions = tabledata "G/L Entry" = rimd,
    tabledata "Vendor Ledger Entry" = rimd,
    tabledata "Cust. Ledger Entry" = rimd;

    trigger OnUpgradePerCompany()
    var
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if not UpgradeTag.HasUpgradeTag('CleanLedgerEntries-003') then
            "CleanLedgerEntries"();
    end;

    local procedure CleanLedgerEntries()
    var
        GL: Record "G/L Entry";
        VL: Record "Vendor Ledger Entry";
        CL: Record "Cust. Ledger Entry";
        UpgradeTag: Codeunit "Upgrade Tag";
    begin
        if GL.FindSet() then begin
            GL.ModifyAll("Vend./Cust. Doc. No.", '');
            GL.ModifyAll("Vend./Cust. Doc. Due Date", 0D);
            GL.ModifyAll(Paid, false);
            GL.ModifyAll("Pmt Cancelled", false);
            Gl.ModifyAll("Bank Document No.", '');
            GL.ModifyAll("Bank Posting Date", 0D);
        end;
        if VL.FindSet() then begin
            VL.ModifyAll("Vend./Cust. Doc. No.", '');
            VL.ModifyAll("Vend./Cust. Doc. Due Date", 0D);
            VL.ModifyAll(Paid, false);
            VL.ModifyAll("Pmt Cancelled", false);
            VL.ModifyAll("Bank Document No.", '');
            VL.ModifyAll("Bank Posting Date", 0D);
        end;
        if CL.FindSet() then begin
            CL.ModifyAll("Vend./Cust. Doc. No.", '');
            CL.ModifyAll("Vend./Cust. Doc. Due Date", 0D);
            CL.ModifyAll(Paid, false);
            CL.ModifyAll("Pmt Cancelled", false);
            CL.ModifyAll("Bank Document No.", '');
            CL.ModifyAll("Bank Posting Date", 0D);
        end;
        UpgradeTag.SetUpgradeTag('CleanLedgerEntries-003');
    end;

}
