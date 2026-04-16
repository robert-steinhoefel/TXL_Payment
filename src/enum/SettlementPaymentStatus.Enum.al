namespace P3.TXL.Payment.Settlement;

// Story 8.1: Payment status of an invoice line relative to its settlements.
// Used by Payment Info Calculator and the Grant Management page extension.
enum 51110 "Settlement Payment Status"
{
    Extensible = false;

    value(0; Open)
    {
        Caption = 'Open';
    }
    value(1; Partial)
    {
        Caption = 'Partial';
    }
    value(2; Paid)
    {
        Caption = 'Paid';
    }
}
