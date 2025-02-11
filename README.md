# Payment extension for TXL

- App object ID ranges: 51100-51149
- Translations: de-DE (XLIFF)
- Platform/Application/Runtime: 25.0.0.0/25.3.0.0/14.0
- Permission Set: "P3.PMT-ALL"
- Namespace: P3.TXL.Payment.{ModuleSpace}

1. [Implemented functionality](#implemented-functionality)
   1. [Relevant Extensions](#relevant-extensions)
   2. [Ledger entry methodology](#ledger-entry-methodology)
   3. [Bank transaction query](#bank-transaction-query)
      1. [API Fields](#api-fields)
2. [ToDos](#todos)
   1. [Megabau](#megabau)
   2. [Partial payments](#partial-payments)
   3. [Line-wise payment balancing / reconciliation](#line-wise-payment-balancing--reconciliation)
3. [Discarded requirements](#discarded-requirements)

## Implemented functionality

[EventSubscribers](./src/codeunit/EventSubscriber.Codeunit.al) for tables Detailed Vendor Ledger Entries and Detailed Customer Ledger Entries are subscribed to OnAfterInsertEvents. These events will trigger a `Codeunit.Run` if the Initial Document is of type "Invoice" or "Credit Memo" and if the Ledger Entry type is Application. The RunTrigger is being ignored.

    if Rec."Entry Type" <> "Detailed CV Ledger Entry Type"::Application then
        exit;
    if Rec."Initial Document Type" = "Gen. Journal Document Type"::Payment then
        exit;
    if Rec."Initial Document Type" = "Gen. Journal Document Type"::Refund then
        exit;
    Codeunit.Run(Codeunit::"Vendor Ledger Entries", Rec);

- [Codeunit VendorLedgerEntries](./src/codeunit/VendorLedgerEntries.Codeunit.al)
- [Codeunit CustomerLedgerEntries](./src/codeunit/CustomerLedgerEntries.Codeunit.al)

### Relevant Extensions
   - [TableExtension 51100](./src/tableextension/GLEntry.TableExt.al),
   - [TableExtension 51101](./src/tableextension/VendorLedgerEntry.TableExt.al),
   - [TableExtension 51102](./src/tableextension/CustLedgerEntry.TableExt.al) and their corresponding 
   - [PageExtension 51100](./src/pageextension/GeneralLedgerEntries.PageExt.al),
   - [PageExtension 51101](./src/pageextension/VendorLedgerEntries.PageExt.al),
   - [PageExtension 51102](./src/pageextension/CustomerLedgerEntries.PageExt.al).

### Ledger entry methodology
Both of these codeunit follow the same methodology an will do the following:

1. Get the corresponding Bank Account Ledger Entry
2. Get the originating Vendor Ledger Entry / Customer Ledger Entry that has been created with the invoice or credit memo document.
3. Add Bank Account Ledger Entry information to Vendor Ledger Entry / Customer Ledger Entry which has been made available through
     - Paid (`Boolean`)
     - Payment Cancelled (`Boolean`)
     - Bank Posting Date (`Date`)
     - Bank Document No. (`Code[20]`)
     - CV Doc. No. (`Code[20]`)
     - CV Doc. Due Date (`Date`)
4. Find corresponding G/L entries for Vendor Ledger Entry / Customer Ledger Entry by their Document No. and Posting Date and add the Bank Account Ledger Entry information accordingly.
5. Add Vendor Ledger Entry / Customer Ledger Entry information by passing the Bank Account Ledger Entry from 1. to the [BankAccountLedgerEntries CodeUnit](./src/codeunit/BankAccountLedgerEntries.Codeunit.al).

If an application is being cancelled, the functionality basically runs "backwards" and removes all previously entered data simply leaving the `Payment Cancelled` field to `true`.

### Bank transaction query
A [BankAccountLedgerEntries Query](./src/query/BankAccountLedgerEntries.Query.al) provides the payment ledger entries as API query.

    EntitySetName = 'CameralisticBankAccountLedgerEntries';
    EntityName = 'CameralisticBankAccountLedgerEntry';
    APIPublisher = 'P3';
    APIVersion = 'v1.0';
    APIGroup = 'CameralisticLedgerEntries';

By using an [Installation Codeunit](./src/codeunit/Installation.Codeunit.al) procedure, the query is automatigically registered to BC's web services.

Currently, we will be resolving the dimensions by the dimension set entry ID being posted with the customer / vendor ledger entry. Due to the concept of queries in BC and their DataItemLink property, the dimension values cannot be exploited in columns next to each other. Instead, they will be listed (linked) by multiple rows to a single Bank Account Ledger Entry resulting in "fake" Bank Account ledger entries that will only differentiate by the `CVDimension_`-values. For use in external analyzations, the field `Entry_No_` should be used to unite these entries.

#### API Fields
| Fieldname              | Field description                                    | Field content/example                            |
| :--------------------- | :--------------------------------------------------- | :----------------------------------------------- |
| Entry_No_              | Bank Account Ledger Entry "Entry No."                |
| BankAccountNo          | Bank Account Ledger Entry "Bank Account No."         |
| AmountLCY              | Bank Account Ledger Entry "Amount (LCY)"             | `Decimal`                                        |
| PostingDate            | Bank Account Ledger Entry "Posting Date"             | `Date`                                           |
| StatementNo            | Bank Account Ledger Entry "Statement No."            |
| BalAccountType         | Bank Account Ledger Entry "Bal. Account Type"        | Enum "Gen. Journal Account Type"                 |
| BalAccountNo           | Bank Account Ledger Entry "Bal. Account No."         |
| CVDocType              | Customer/Vendor Ledger Entry Document Type           | Invoice/Credit Memo                              |
| CVDocNo                | Customer/Vendor Ledger Entry Document No.            | RG-251001                                        |
| CVDocDueDate           | Customer/Vendor Ledger Entry Document Due Date       | `Date`                                           |
| CVGlobalDimension1Code | Customer/Vendor Ledger Entry Global Dimension 1 Code |
| CVGlobalDimension2Code | Customer/Vendor Ledger Entry Global Dimension 2 Code |
| CVDimensionSetID       | Customer/Vendor Ledger Entry Dimension Set ID        | `Integer`                                        |
| LedgerEntryType        | Source Ledger Entry Entry Type                       | `Customer`/`Vendor`/`G/L Account`                |
| **>>> BEGIN**          | **DataItemLink = "Dimension Set ID" =**              | **BankAccountLedgerEntry."CV Dimension Set ID"** |
| CVDimension_Code       | Bank Account Ledger Entry "Dimension Code"           |
| CVDimension_Value_Code | Customer/Vendor Ledger Entry "Dimension Value Code"  |
| CVDimension_Value_Name | Customer/Vendor Ledger Entry "Dimension Value Name"  |
| **<<< END OF**         | **DATAITEMLINK**                                     |                                                  |
| BankLEGlobDim1         | Bank Account Ledger Entry "Global Dimension 1 Code"  |
| BankLEGlobDim2         | Bank Account Ledger Entry "Global Dimension 2 Code"  |
| BankLEDimSetID         | Bank Account Ledger Entry "Dimension Set ID"         | `Integer`                                        |

## ToDos
### Megabau
The implementaion to **MEGABAU** is still missing. The app must be made dependant on this extension to be able to extend the corresponding tables and subscribe to their OnAfterInsert triggers (`Vend. Adv. Pay. Led. EntryMGB (1010772)` / `Cust. Adv. Pay. Led. EntryMGB (1010770)`).

### Partial payments
Partial payments are currently not being processed. They will be treated as "full payments" to a C/V ledger entry.

### Line-wise payment balancing / reconciliation
Also a line-wise treatment of payments / refunds is not taken into account. There  discussions to be held with TXL on how to deal with those. For the time being it seems that there are no partial Vendor or Customer payments at all or they haven't been taking these into account themselves yet. We will most likely need a line-wise matching of payments to correctly post spendings to Cost Centers, Planning Objects (Cost accounting) and Fundings as well as payment discounts (German: "Skonto").

## Discarded requirements
Since the cameralistic reporting will be based on the Bank Account Ledger Entries only, there is currently no need for an extended General Journal posting functionality that moves bank account posting information across G/L entries.