# Payment extension for TXL

- App object ID ranges: 51100-51149
- Translations: de-DE (XLIFF)
- Platform/Application/Runtime: 25.0.0.0/25.3.0.0/14.0
- Permission Set: "P3.PMT-ALL"
- Namespace: P3.TXL.Payment.{ModuleSpace}

1. [Implemented functionality](#implemented-functionality)
2. [ToDos](#todos)
   1. [Megabau](#megabau)
   2. [Partial payments](#partial-payments)
   3. [Line-wise payment balancing / reconciliation](#line-wise-payment-balancing--reconciliation)
3. [Discarded requirements](#discarded-requirements)

## Implemented functionality

Please refer to the [English documentation](./Documentation-EN.md) or [German documentation](./Documentation-DE.md) which are also available as HTML and PDF files.

## ToDos
### Megabau
The implementaion to **MEGABAU** is still missing. The app must be made dependant on this extension to be able to extend the corresponding tables and subscribe to their OnAfterInsert triggers (`Vend. Adv. Pay. Led. EntryMGB (1010772)` / `Cust. Adv. Pay. Led. EntryMGB (1010770)`).

### Partial payments
Partial payments are currently not being processed. They will be treated as "full payments" to a C/V ledger entry.

### Line-wise payment balancing / reconciliation
Also a line-wise treatment of payments / refunds is not taken into account. There are discussions to be held with TXL on how to deal with those. For the time being it seems that there are no partial Vendor or Customer payments at all or they haven't been taking these into account themselves yet. We will most likely need a line-wise matching of payments to correctly post spendings to Cost Centers, Planning Objects (Cost accounting) and Fundings as well as payment discounts (German: "Skonto").

## Discarded requirements
Since the cameralistic reporting will be based on the Bank Account Ledger Entries only, there is currently no need for an extended General Journal posting functionality that moves bank account posting information across G/L entries.