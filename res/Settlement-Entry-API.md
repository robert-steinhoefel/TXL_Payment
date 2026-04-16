# Settlement Entry API (`settlementEntries`)

OData API page (page 51102) exposing **Settlement Entry** (table 51106) for Power BI and external consumers.

## Endpoint

```
GET /api/p3group/txlPayment/v1.0/companies({id})/settlementEntries
```

- **Authentication:** OAuth 2.0 (BC SaaS) or Basic Auth (on-prem)
- **Read-only:** INSERT / MODIFY / DELETE are disabled

## Key Field

`entryNo` (`Entry No.`, integer, auto-increment) is the OData primary key (`ODataKeyFields`).
Each row represents one Settlement Entry: a single payment allocation of a specific amount
against a specific document line.

## Classification Fields

| Field                 | Values                                  |
| --------------------- | --------------------------------------- |
| `transactionType`     | `Sales` \| `Purchase`                   |
| `documentType`        | `Invoice` \| `Credit Memo`              |
| `settlementEntryType` | `Normal` \| `Unallocated` \| `Reversal` |

- **Normal** — standard entry created on payment/application.
- **Unallocated** — overpayment remainder not yet linked to a document line;
  `documentNo` is intentionally blank for these rows.
- **Reversal** — created when a payment or CM application is unapplied;
  amounts carry the **opposite sign** of the original entry.
  Use `reversalEntry = true` and `originalEntryNo` to join back to the reversed entry.

## Document Reference

`documentNo` / `documentLineNo` identify the posted invoice or credit memo line
that this settlement entry belongs to.

## Amounts (all LCY)

| Field                                        | Content                                                                                             |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `settlementAmt` / `settlementAmtInclVat`     | Portion of the payment allocated to this line                                                       |
| `cashDiscountAmt` / `cashDiscountAmtInclVat` | Cash discount distributed to this line                                                              |
| `originalLineAmt` / `originalLineAmtInclVat` | Snapshot of the source document line amount at entry creation (for variance reporting)              |
| `nonDeductibleVatAmt`                        | Non-deductible VAT portion of the line                                                              |
| `totalSettledAmtInclVat` / `totalSettledAmt` | `settlementAmt + cashDiscountAmt` — denormalised for the FlowField sum on the source document table |

Reversal entries carry **negative** amounts; net of original + reversal = 0.

## Fully Settled Flags

- `lineFullySettled` — `true` once the total settled amount for this document line reaches
  the original line amount (within a ±0.01 rounding tolerance).
- `documentFullySettled` — `true` once the invoice/credit memo CLE `Remaining Amount` reaches 0.

Both flags are written on **all** Settlement Entries for the affected line/document after every
insert or reversal, so Power BI can filter on current settlement state without aggregating.

> **Known gap:** For a CM applied before a payment (separate transactions), the CM entries get
> `documentFullySettled = false` at creation time and are never back-updated when the payment
> later closes the document. Payment entries are always reliable.

## Dimensions

All 8 shortcut dimension **codes** (`globalDimension1Code` … `shortcutDimension8Code`) are stored
directly on the record — no joins or CalcFields required. OData `$filter` on any dimension code
is index-backed.

Dimension **names** are not stored here. To resolve a code to its display name:
- Join against the standard BC `dimensionValues` API endpoint using the dimension code as key, or
- Build a Power BI lookup table from that endpoint.

`dimensionSetId` is included as a bridge to the standard Dimension Set Entry API for consumers
that need to enumerate all dimension values beyond the 8 shortcuts.

## G/L Account

`glAccountNo` / `glAccountName` — G/L account and its name, snapshotted at entry creation.

## Customer / Vendor

`cvNo` / `cvName` — customer or vendor number and name (snapshot; does not update on rename).
Disambiguate using `transactionType`: `Sales` → customer, `Purchase` → vendor.

## Reversal Chain

| Field             | Content                                                     |
| ----------------- | ----------------------------------------------------------- |
| `reversalEntry`   | `true` if this row is a reversal of another entry           |
| `originalEntryNo` | `entryNo` of the entry being reversed (0 if not a reversal) |
| `reversed`        | `true` on the original entry once it has been reversed      |
| `reversalEntryNo` | `entryNo` of the reversal entry (0 if not yet reversed)     |

## Delta Queries / Incremental Refresh

`ChangeTrackingAllowed = true` enables OData `$deltatoken`. Power BI incremental refresh
can request only rows created or modified since the previous refresh instead of reloading
the full table. Use `systemModifiedAt` as the incremental refresh boundary.

## System Fields

`systemId`, `systemCreatedAt`, `systemModifiedAt`, `systemCreatedBy`, `systemModifiedBy`
are exposed automatically by the BC OData layer for all custom-table API pages —
no explicit field declarations needed.

## Omitted Fields

`sourceTransactionNo` / `sourcePaymentCLEEntryNo` — internal deduplication guards used by
`SettlementEntryMgt`; not relevant for reporting.
