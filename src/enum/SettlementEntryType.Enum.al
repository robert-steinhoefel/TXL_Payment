namespace P3.TXL.Payment.Settlement;

enum 51103 "Settlement Entry Type"
{
    Extensible = true;

    value(0; Normal)
    {
        Caption = 'Normal';
    }
    value(1; Unallocated)
    {
        Caption = 'Unallocated';
    }
    value(2; Reversal)
    {
        Caption = 'Reversal';
    }
}
