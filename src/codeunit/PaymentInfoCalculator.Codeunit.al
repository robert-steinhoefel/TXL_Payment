namespace P3.TXL.Payment.Settlement;

using Microsoft.Sales.History;

// Story 8.1: Derives the payment status of a Sales Invoice Line from its settled/outstanding amounts.
// Kept as a standalone codeunit so the logic is reusable across page extensions (Story 8.1, 8.2 etc.)
// without duplicating the derivation rule.
//
// Prerequisite: caller must have called CalcFields on the Sales Invoice Line record for
// "Settled Amt (LCY)" before passing it here — this codeunit does not call CalcFields itself
// to avoid repeated database roundtrips when the caller already has current values.
codeunit 51111 "Payment Info Calculator"
{
    procedure GetPaymentStatus(SalesInvLine: Record "Sales Invoice Line"): Enum "Settlement Payment Status"
    begin
        if SalesInvLine."Settled Amt (LCY)" = 0 then
            exit("Settlement Payment Status"::Open);

        if SalesInvLine."Outstanding Amt (LCY)" > 0 then
            exit("Settlement Payment Status"::Partial);

        exit("Settlement Payment Status"::Paid);
    end;

    procedure GetPaymentStatusStyle(Status: Enum "Settlement Payment Status"): Text
    begin
        case Status of
            "Settlement Payment Status"::Paid:
                exit('Favorable');
            "Settlement Payment Status"::Partial:
                exit('Ambiguous');
            else
                exit('');
        end;
    end;
}
