namespace P3.TXL.Payment.System;

enum 51100 "Source Ledger Entry Type"
{
    Extensible = true;

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Customer)
    {
        Caption = 'Customer';
    }
    value(2; Vendor)
    {
        Caption = 'Vendor';
    }
    value(3; "G/L Account")
    {
        Caption = 'G/L Account';
    }
}
