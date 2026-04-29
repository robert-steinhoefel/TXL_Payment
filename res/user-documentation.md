# TXL Payment – User Documentation

## Overview

The TXL Payment extension adds cameralistic payment settlement tracking to Microsoft Dynamics 365 Business Central. Instead of recording payments only at the document level, every payment is broken down to the individual invoice or credit memo line. This gives finance teams a precise, line-by-line view of what has been paid, when, and from which bank transaction – without replacing Business Central's standard application logic.

> **Current scope:** This extension covers the **sales (accounts receivable) side only.** Settlement entries are created for posted sales invoices and sales credit memos.

The extension adds two main pages you will work with:

- **Settlement Entries** – a permanent, read-only audit log of every payment allocation event
- **Payment Allocation Worksheet** – a modal dialogue that appears when a partial payment requires manual distribution across lines

---

## Settlement Entries

### What the page shows

The Settlement Entries page lists every settlement record created by the extension. Each row represents the allocation of a payment (or credit memo application, or reversal) to one specific line of a posted sales invoice or sales credit memo. Only sales-side documents appear here in the current version.

**Key columns visible by default:**

| Column                               | Description                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Entry Type                           | Whether this is a *Normal* settlement, an *Unallocated* amount (overpayment remainder), or a *Reversal*                               |
| Transaction Type                     | *Sales* or *Purchase* – which side of the ledger the settlement belongs to. In the current version, only *Sales* entries are created. |
| Document Type                        | *Invoice* or *Credit Memo*                                                                                                            |
| Document No.                         | The posted invoice or credit memo number                                                                                              |
| Customer No.                         | The customer at the time of settlement                                                                                                |
| Customer Name                        | Snapshot of the customer name at the time of settlement                                                                               |
| Settlement Date                      | The posting date of the payment that triggered the settlement                                                                         |
| Settlement Amount (LCY)              | The net amount settled on this line, *excluding* VAT                                                                                  |
| Original Line Amount (LCY)           | Snapshot of the invoice line amount (excl. VAT) at the moment of settlement                                                           |
| Original Line Amount Incl. VAT (LCY) | Snapshot of the invoice line amount *including* VAT                                                                                   |
| Non-Deductible VAT Amount (LCY)      | Non-deductible VAT portion of this line at settlement time                                                                            |
| Reversal Entry                       | Ticked if this entry was created to reverse a prior settlement                                                                        |
| Reversed                             | Ticked if this original entry has already been reversed                                                                               |
| Bank Statement Document No.          | Reference to the bank statement document that carried the payment                                                                     |
| Description                          | Free-text description of the settlement                                                                                               |

Additional columns (hidden by default, can be made visible via *Choose Columns*):

| Column                               | Description                                                                                                                             |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Assignment ID                        | Groups all settlement entries belonging to the same payment event. Format: `{Customer No.}-{YYMMDD}-{SeqNo}`, e.g. `CUST001-260312-001` |
| Settlement Amount Incl. VAT (LCY)    | Settled amount including VAT                                                                                                            |
| Cash Discount Amount (LCY)           | Cash discount granted on this settlement (excl. VAT)                                                                                    |
| Cash Discount Amount Incl. VAT (LCY) | Cash discount including VAT                                                                                                             |
| Line Fully Settled                   | Indicates that this specific invoice line has been fully paid                                                                           |
| Document Fully Settled               | Indicates that all lines of the document have been fully paid                                                                           |
| G/L Account No. / Name               | The revenue or expense account from the invoice line                                                                                    |
| Grant Number                         | Grant reference for public-sector grant accounting                                                                                      |
| Created By / Created Date/Time       | Audit information about who triggered the creation                                                                                      |

---

### How settlement entries are created

Settlement entries are created automatically by the extension whenever Business Central applies a payment to an invoice. You do not create them manually. There are three scenarios:

#### Full settlement

When a payment exactly covers (or slightly over-pays) an invoice so that the invoice becomes fully closed, the extension distributes the payment across all invoice lines proportionally. For each line, one settlement entry is written.

*Proportional distribution* means: each line receives a share of the total payment equal to its share of the total invoice amount. The last line absorbs any rounding differences.

If the invoice was closed with a **cash discount**, the discount amount is recorded in the `Cash Discount Amount` fields of the relevant settlement entry. The discount is only populated when a single payment closes the invoice; if multiple payments were made beforehand, the discount cannot be unambiguously attributed to one payment and is left at zero.

#### Partial payment

When a payment covers only part of an invoice (the invoice remains open after posting), the extension prompts the user with the **Payment Allocation Worksheet** before the payment is posted. See the section below for full details. After the user confirms the allocation, one settlement entry is created per line that received an allocation amount.

#### Credit memo application

When a credit memo is applied against an invoice, the extension treats the credit application the same way as a payment: it creates settlement entries for each invoice line covered by the credit, reflecting the reduction in the outstanding balance.

#### Overpayment (Unallocated entry)

If a payment exceeds the total invoice amount, the excess is captured as an **Unallocated** settlement entry. This entry has no document number – the empty document number in the list is the visual indicator that this amount has not yet been attributed to a specific line. The entry shares the same Assignment ID as the other settlement entries for that payment event and can be consumed when a subsequent application is made.

#### Reversal (Unapplication)

When a payment application is reversed in Business Central (via *Unapply Customer Ledger Entries*), the extension automatically creates a reversal settlement entry for each original entry affected. Reversal entries carry opposite signs to the originals, so that summing all entries for a document line always yields the correct net outstanding amount. The original entries are flagged `Reversed = true` and the reversal entries are flagged `Reversal Entry = true`. Both always remain in the list; no entries are ever deleted.

---

### Reading the Settlement Entries list

A few practical points when reading the list:

- **Entries with a blank Document No.** are Unallocated entries (overpayment surplus). They are normal and expected when a customer pays slightly more than the invoice total.
- **Negative amounts** are reversals. They cancel out the positive amounts from the original settlement. The net of all entries for a given document line equals the currently outstanding balance reduction.
- **Multiple entries for the same invoice** are normal. One row appears for every line of the invoice, and another set of rows for each subsequent partial payment.
- The **Assignment ID** ties together all entries from one payment event. You can filter or group by this column to see every line affected by a single bank transfer.

---

## Payment Allocation Worksheet

### When it appears

The Payment Allocation Worksheet opens automatically – as a modal dialogue – immediately before a partial payment is posted. The system detects that the payment amount is less than the invoice's remaining open balance and interrupts the posting to ask you how the payment should be distributed across the individual invoice lines.

This happens in two places:

- When posting a **General Journal** batch that contains a payment applied to a sales invoice
- When using **Apply Customer Ledger Entries** to manually apply a posted payment to a posted sales invoice

If you cancel the worksheet, the entire payment posting is rolled back. Nothing is posted until you confirm a valid allocation.

### Layout of the worksheet

**Header area:**

| Field                          | Description                                                                                    |
| ------------------------------ | ---------------------------------------------------------------------------------------------- |
| Customer No.                   | The customer the invoice belongs to                                                            |
| Customer Name                  | Name of the customer                                                                           |
| Document No.                   | The invoice being partially paid                                                               |
| Payment Amount Incl. VAT (LCY) | The full amount of the incoming payment, including VAT                                         |
| Total Allocated                | Running total of what you have allocated across the lines so far                               |
| Remaining to Allocate          | Difference between Payment Amount and Total Allocated – must reach zero before you can confirm |

**Line area (one row per invoice line):**

| Column                           | Description                                                                                          |
| -------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Line No.                         | Line number from the original invoice                                                                |
| Description                      | Description from the invoice line                                                                    |
| G/L Account No.                  | Revenue account of the line                                                                          |
| Original Amount (LCY)            | Invoice line amount excl. VAT                                                                        |
| Original Amount Incl. VAT (LCY)  | Invoice line amount incl. VAT                                                                        |
| Already Settled Amount (LCY)     | Amount already paid on this line from previous partial payments (zero on first payment)              |
| Allocated Amount Incl. VAT (LCY) | **The field you edit.** Enter how much of this payment should be applied to this line, including VAT |

### Entering a manual allocation

1. Review the **Original Amount Incl. VAT** and **Already Settled Amount** columns to understand what is still outstanding per line.
2. In the **Allocated Amount Incl. VAT (LCY)** column, enter the amount you wish to apply to each line.
3. Watch the **Remaining to Allocate** figure in the header. It must reach exactly zero (or within rounding tolerance) before you can confirm.
4. Choose **Apply Allocation** to confirm and continue with posting.

The system internally back-calculates the net amount (excl. VAT) from the gross amount you enter, using the VAT ratio of the original invoice line.

### Distribute Proportionally

If you do not want to allocate manually, choose **Distribute Proportionally**. The system calculates the remaining outstanding balance per line (original amount minus already settled) and distributes the payment in the same proportions. The last line absorbs any rounding difference. You can use this as a starting point and then adjust individual lines before confirming.

### Cancelling

Choosing **Cancel** discards all entered amounts and rolls back the entire payment application. The journal line or the manual application is abandoned; nothing is posted. You can return to the journal or application page and correct the amounts before trying again.

---

## Status indicators on invoice lines

The extension adds a payment status indicator to posted sales invoice lines. The status is derived dynamically from the net settlement amounts:

| Status      | Meaning                                                                                    |
| ----------- | ------------------------------------------------------------------------------------------ |
| **Open**    | No settlement entries exist for this line, or all settlements have been reversed           |
| **Partial** | Some settlement entries exist but the outstanding balance has not yet been reduced to zero |
| **Paid**    | The sum of all settlement amounts equals the line amount (within a tolerance of 0.01 LCY)  |

The status is displayed in colour: green for *Paid*, amber for *Partial*, and default (no colour) for *Open*.

The **Outstanding Amount (LCY)** field on each invoice line shows the numeric balance remaining, calculated as: *Original Line Amount – Total Net Settled Amount*.

---

## Assignment ID

Every payment event is assigned a unique **Assignment ID** in the format `{Customer No.}-{YYMMDD}-{SeqNo}`, for example `CUST001-260312-001`. All settlement entries created by a single payment – whether across multiple invoice lines or including an Unallocated entry – share the same Assignment ID.

Use the Assignment ID to:

- Group all settlement rows for one bank transfer
- Trace which invoice lines were covered by a specific payment in the Power BI reports
- Understand whether an Unallocated entry belongs to the same bank transfer as a group of normal settlements

---

## Frequently asked questions

**Why does an invoice line show "Partial" even though I entered a full payment?**
The system calculates status from the net of all settlement entries, including reversals. If a previous settlement was reversed, the net balance is lower than expected. Check the Settlement Entries list filtered by the invoice number to see all entries and reversals.

**Can I edit settlement entries?**
No. Settlement entries are an immutable audit log. If a settlement is incorrect, the payment application must be reversed in Business Central using the standard unapplication function. The extension will then automatically create the corresponding reversal settlement entries.

**Why is the Bank Statement Document No. empty on some entries?**
This field is only populated when the system can trace the payment back to a specific bank account ledger entry at the time of settlement creation. If a settlement is created through a manual CLE application that is not directly linked to a bank account posting, the field may be empty.

**What happens if I close the Payment Allocation Worksheet without allocating all amounts?**
The **Apply Allocation** action is only enabled when the Remaining to Allocate field reaches zero. If you close the window with the Cancel button instead, the posting is fully rolled back.

**Can two payments be allocated in the same journal batch?**
Yes. The worksheet opens once for each partial application detected in the batch. Each one must be confirmed before posting proceeds.
