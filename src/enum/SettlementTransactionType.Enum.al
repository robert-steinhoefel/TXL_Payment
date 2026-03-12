namespace P3.TXL.Payment.Settlement;

enum 51102 "Settlement Transaction Type"
{
    Extensible = true;

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Sales)
    {
        Caption = 'Sales';
    }
    value(2; Purchase)
    {
        Caption = 'Purchase';
    }
}
