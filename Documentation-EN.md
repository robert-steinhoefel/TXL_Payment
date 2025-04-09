# P3 TXL Payment Extension: Cameralistic  
  
## Management Summary  
  
This application is an individual customisation of Microsoft Dynamics Business Central 365. It links payment information with the corresponding invoice information and thus enables an accounting evaluation according to cameralistic aspects.  
  
To make this technically possible, some ledger entry tables are supplemented with individual columns that are filled during the payment settlement process. In addition, a separate query is implemented that enables the retrieval of the payment ledger entries, supplemented by the invoice information, via a REST API.

1. [Management Summary](#management-summary)
2. [Implemented Objects](#implemented-objects)
   1. [Object Overview](#object-overview)
   2. [Source Ledger Entry Type (Enum)](#source-ledger-entry-type-enum)
   3. [P3.PMT-ALL (Permission Set)](#p3pmt-all-permission-set)
   4. [Installation (Codeunit)](#installation-codeunit)
   5. [Update Codeunit (Codeunit)](#update-codeunit-codeunit)
   6. [Event Subscriber (Codeunit)](#event-subscriber-codeunit)
   7. [Customer Ledger Entries / Vendor Ledger Entries (Codeunit)](#customer-ledger-entries--vendor-ledger-entries-codeunit)
   8. [Bank Account Ledger Entries (Codeunit)](#bank-account-ledger-entries-codeunit)
      1. [customer/vendor ledger entry](#customervendor-ledger-entry)
      2. [General ledger entry](#general-ledger-entry)
   9. [Table Extensions](#table-extensions)
      1. ["Bank Acc. Ledger Entry](#bank-acc-ledger-entry)
      2. [Cust. Ledger Entry (customer ledger entry)](#cust-ledger-entry-customer-ledger-entry)
         1. [Vendor Ledger Entry](#vendor-ledger-entry)
      3. [G/L Entry (general ledger entry)](#gl-entry-general-ledger-entry)
      4. [Dimension Set Entry](#dimension-set-entry)
   10. [Bank Account Ledger Entries (query)](#bank-account-ledger-entries-query)
       1. [API Fields](#api-fields)

  
## Implemented Objects  
  
The objects listed below have been added as part of this extension.  
  
### Object Overview  
  
| Object type     | First ID | Last ID |
| --------------- | -------- | ------- |
| Table           | N/A      | N/A     |
| Table extension | 51100    | 51105   |
| Page            | N/A      | N/A     |
| Page extension  | 51100    | 51103   |
| Enum            | 51100    | 51100   |
| Query           | 51100    | 51100   |
| Codeunit        | 51100    | 51105   |
  
### Source Ledger Entry Type (Enum)
  
| Key | Value       | Description |
| --- | ----------- | ----------- |
| 0   | ‘ “         | ” ’         |
| 1   | Customer    | Customer    |
| 2   | Vendor      | Vendor      |
| 3   | G/L Account | G/L Account |
  
### P3.PMT-ALL (Permission Set)  
  
The permission set contains all permissions to use the functionalities of the extension without restriction.  
  
### Installation (Codeunit)  
  
This codeunit is automatically executed when the extension is installed.  
It adds an entry to the ‘Tenant Web Service’ table for querying the bank account ledger entries and publishes it. The web service has the service name `CameralisticBankAccountLedgerEntries`.  
  
### Update Codeunit (Codeunit)  
  
This codeunit is automatically executed when the extension is updated. It currently has no content and is not used.  
  
### Event Subscriber (Codeunit)  
  
This code unit subscribes to system-internal events and then calls certain functions.  
  
Three events are subscribed to in the extension:  
- `OnAfterInsertEvent` of the `Detailed Vendor Ledg. Entry` table  
- `OnAfterInsertEvent` of the `Detailed Cust. Ledg. Entry` table  
- `OnAfterInsertEvent` of the `G/L Entry` table  
  
These events for the detailed vendor/customer ledger entries are triggered whenever a new detailed vendor/customer ledger entry is created in the system.  
  
These two events call an almost identical procedure. The system checks whether the entry triggering this event  
- is a temporary data record,  
- does not correspond to the ‘application’ entry type,  
- has ‘payment’ or ‘refund’ as the original document type.  
If none of these three conditions apply, a code unit is called that executes the core functionality of the extension based on the detailed vendor/customer ledger entry. The code unit called is one of those listed below [[#Customer Ledger Entries / Vendor Ledger Entries (Codeunit)]].  
  
The restriction ensures that the subsequent codeunit is only called when posting a ledger entry application or un-application (and not already when posting an invoice or payment).  
  
The **third event** is always triggered when a new general ledger entry is created. The triggered method checks whether this event is triggered by a ledger entry that  
- is a temporary data record,  
- whose balancing account is not a bank account.  
If neither of these conditions applies, the corresponding bank ledger entry is identified. Together with the G/L ledger entry, this is transferred directly to the [[#Bank Account Ledger Entries (Codeunit)]] (see section [[#G/L Ledger Entries]]) for further processing.  
### Customer Ledger Entries / Vendor Ledger Entries (Codeunit)  
  
These two code units run identically and are therefore explained in the same section. In the following, however, only the customer is mentioned in the wording. This is to be equated with the term ‘vendor’ for the reciprocal case. In the case of an applcation entry or when posting an un-application, the code units determine the invoice/credit memo ledger entries, G/L entries and bank account ledger entries to be processed.  
  
On the basis of the detailed customer ledger entry, which is transferred from the [[#Event Subscriber (Codeunit)]] to the code unit, the detailed customer ledger entry and customer ledger entries that define the payment ledger entry are determined. The corresponding bank account ledger entry is identified with the help of this payment ledger entry.  
  
The customer ledger entry from the *invoice* or credit memo and the general ledger entry belonging to this customer ledger entry are updated with the information from the bank account ledger entry and the payment ledger entry:  
- The ‘Paid’ indicator is set,  
- The posting date of the bank account ledger entry is entered as the bank posting date,  
- The document number (usually the account statement number) of the bank account ledger entry is entered as the bank document number,  
- In addition, the due date of the invoice or credit memo is entered in the general ledger entry.  
  

Finally, the bank account ledger entry determined is transferred to the [[#Bank Account Ledger Entries (Codeunit)]] together with the invoice ledger entry, in order to update the bank account ledger entry with the corresponding information.  
  
If clearing of an item is cancelled, all the above information is removed from the ledger entries. In addition, the ‘payment cancelled’ indicator is set. This is to ensure that it remains clear why there are shifts in the cameralistic evaluations.  
  
### Bank Account Ledger Entries (Codeunit)  
  
This code unit transfers the information from a payment or refund cleared invoice or credit memo ledger entry to the corresponding bank account ledger entry. It is accessed exclusively via the [[#Customer Ledger Entries / Vendor Ledger Entries (Codeunit)]] code units.  
The code unit throws an error if you try to process a  
  
#### customer/vendor ledger entry  
Customer ledger entries and vendor ledger entries are treated identically, which is why only customer ledger entries are mentioned by name in the following.  
  
First, the system checks whether the invoice or credit memo number of the customer ledger entry already exists in the bank account ledger entry as the customer/vendor document number. If this is the case, the execution for this data record is terminated.  
If another invoice or credit memo number has already been entered in the bank account ledger entry, the number from the current data record is appended, separated by a pipe character (`|`). If the due date of the new ledger entry falls *after* the already existing customer/vendor due date, it will be overwritten. Otherwise, it remains. So the later due date is always entered.  
If the total length of the customer/vendor document number string is longer than 20 characters, the excess characters are truncated on the right.  
  
The following are then transferred from the customer ledger entry to the corresponding fields of the bank account ledger entry:  
- the due date,  
- the type of entry (debtor, creditor or general ledger entry)  
- the type of document (invoice or credit note)  
- the global dimension 1 code  
- the global dimension 2 code  
- the dimension record entry ID  
  
#### General ledger entry  
If a bank account ledger entry is posted directly to a G/L account, the information from the general ledger entry is transferred to the bank account ledger entry in the same way as for customer/vendor entries. However, there are the following differences:  
- Since a general ledger entry has no due date, the customer/vendor ledger entry due date is not set in either the general ledger entry or the bank account ledger entry and remains empty.  
  
If a bank transaction that was posted directly to a G/L account is cancelled using the ‘Reverse Transaction’ function from the BC standard, all set information is removed again. In addition, the ‘Payment Cleared’ indicator is set for all affected ledger entries, i.e. both the original and the correction ledger entries.  
### Table Extensions  
  
The following table extensions have been implemented. The corresponding pages have also been added to allow the table columns to be displayed.  
  
#### "Bank Acc. Ledger Entry 
  
| Field no. | Field name                 | Field type                                                                   |
| --------- | -------------------------- | ---------------------------------------------------------------------------- |
| 51100     | Ledger Entry Type          | Enum ‘Source Ledger Entry Type’                                              |
| 51101     | CV Doc. No.                | Code[20] <br>TableRelation, conditionally dependent on the Ledger Entry Type |
| 51102     | CV Doc. Due Date           | Date                                                                         |
| 51103     | CV Doc Type                | Enum ‘Gen. Journal Document Type’                                            |
| 51104     | CV Global Dimension 1 Code | Code[20] <br>TableRelation                                                   |
| 51105     | CV Global Dimension 2 Code | Code[20] <br>TableRelation                                                   |
| 51106     | CV Dimension Set ID        | Integer <br>TableRelation                                                    |
  
#### Cust. Ledger Entry (customer ledger entry)  
  
| Field No. | Field Name        | Field Type |
| --------- | ----------------- | ---------- |
| 51100     | Paid              | Boolean    |
| 51101     | Pmt Cancelled     | Boolean    |
| 51102     | Bank Posting Date | Date       |
| 51103     | Bank Document No. | Code[20]   |
  
##### Vendor Ledger Entry  
  
| Field No. | Field Name        | Field Type |
| --------- | ----------------- | ---------- |
| 51100     | Paid              | Boolean    |
| 51101     | Pmt Cancelled     | Boolean    |
| 51102     | Bank Posting Date | Date       |
| 51103     | Bank Document No. | Code[20]   |
  
#### G/L Entry (general ledger entry)  
  
| Field no. | Field name        | Field type |
| --------- | ----------------- | ---------- |
| 51100     | Paid              | Boolean    |
| 51101     | Pmt Cancelled     | Boolean    |
| 51102     | Bank Posting Date | Date       |
| 51103     | Bank Document No. | Code[20]   |
| 51105     | CV Doc. Due Date  | Date       |

#### Dimension Set Entry  
  
A new field group of type DropDown has been defined in the dimension record items. It contains the fields ‘Dimension Code’, ‘Dimension Value Code’ and ‘Dimension Value Name’.  
  
This field group is used to improve the display of the table relation in the bank account ledger entries.

### Bank Account Ledger Entries (query)
A custom query provides the payment ledger entries as API query.

    EntitySetName = 'CameralisticBankAccountLedgerEntries';
    EntityName = 'CameralisticBankAccountLedgerEntry';
    APIPublisher = 'P3';
    APIVersion = 'v1.0';
    APIGroup = 'CameralisticLedgerEntries';

By using the [Installation Codeunit](#installation-codeunit), the query is automatitically registered to BC's web services.

Currently, the dimensions are resolved by the dimension set entry ID being posted with the customer / vendor ledger entry. Due to the concept of queries in BC and their DataItemLink property, the dimension values cannot be exploited in columns next to each other. Instead, they will be listed by multiple rows, resulting in "fake" Bank Account ledger entries that will only differentiate by the `CVDimension_`-values. For use in external analyzations, the field `Entry_No_` should be used to re-unite these entries.

#### API Fields
| Fieldname              | Field description                                    | Field type                                       |
| :--------------------- | :--------------------------------------------------- | :----------------------------------------------- |
| Entry_No_              | Bank Account Ledger Entry "Entry No."                | `Integer`                                        |
| BankAccountNo          | Bank Account Ledger Entry "Bank Account No."         | `Code[20]`                                       |
| AmountLCY              | Bank Account Ledger Entry "Amount (LCY)"             | `Decimal`                                        |
| PostingDate            | Bank Account Ledger Entry "Posting Date"             | `Date`                                           |
| StatementNo            | Bank Account Ledger Entry "Statement No."            | `Code[20]`                                       |
| BalAccountType         | Bank Account Ledger Entry "Bal. Account Type"        | Enum "Gen. Journal Account Type"                 |
| BalAccountNo           | Bank Account Ledger Entry "Bal. Account No."         | `Code[20]`                                       |
| CVDocType              | Customer/Vendor Ledger Entry Document Type           | Invoice/Credit Memo                              |
| CVDocNo                | Customer/Vendor Ledger Entry Document No.            | RG-251001                                        |
| CVDocDueDate           | Customer/Vendor Ledger Entry Document Due Date       | `Date`                                           |
| CVGlobalDimension1Code | Customer/Vendor Ledger Entry Global Dimension 1 Code | `Code[20]`                                       |
| CVGlobalDimension2Code | Customer/Vendor Ledger Entry Global Dimension 2 Code | `Code[20]`                                       |
| CVDimensionSetID       | Customer/Vendor Ledger Entry Dimension Set ID        | `Integer`                                        |
| LedgerEntryType        | Source Ledger Entry Entry Type                       | Enum "Source Ledger Entry Type"                  |
| **>>> BEGIN**          | **DataItemLink = "Dimension Set ID" =**              | **BankAccountLedgerEntry."CV Dimension Set ID"** |
| CVDimension_Code       | Bank Account Ledger Entry "Dimension Code"           | `Code[20]`                                       |
| CVDimension_Value_Code | Customer/Vendor Ledger Entry "Dimension Value Code"  | `Code[20]`                                       |
| CVDimension_Value_Name | Customer/Vendor Ledger Entry "Dimension Value Name"  | `Code[20]`                                       |
| **<<< END OF**         | **DATAITEMLINK**                                     |                                                  |
| BankLEGlobDim1         | Bank Account Ledger Entry "Global Dimension 1 Code"  | `Code[20]`                                       |
| BankLEGlobDim2         | Bank Account Ledger Entry "Global Dimension 2 Code"  | `Code[20]`                                       |
| BankLEDimSetID         | Bank Account Ledger Entry "Dimension Set ID"         | `Integer`                                        |