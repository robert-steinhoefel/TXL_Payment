namespace P3.TXL.Payment.Settlement;

// API documentation: Settlement-Entry-API.md (project root)
page 51102 "Settlement Entry API"
{
    PageType = API;
    APIVersion = 'v1.0';
    APIPublisher = 'p3group';
    APIGroup = 'txlPayment';
    EntityName = 'settlementEntry';
    EntitySetName = 'settlementEntries';
    Caption = 'Settlement Entry API';
    SourceTable = "Settlement Entry";
    ODataKeyFields = "Entry No.";
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    // ChangeTrackingAllowed enables OData delta queries ($deltatoken) in Power BI,
    // so incremental refresh only fetches new/changed rows instead of the full table.
    ChangeTrackingAllowed = true;

    layout
    {
        area(Content)
        {
            // ── Primary Key ───────────────────────────────────────────────────
            field(entryNo; Rec."Entry No.")
            {
                Caption = 'Entry No.';
            }

            // ── Source Classification ─────────────────────────────────────────
            field(transactionType; Rec."Transaction Type")
            {
                Caption = 'Transaction Type';
            }
            field(documentType; Rec."Document Type")
            {
                Caption = 'Document Type';
            }
            field(settlementEntryType; Rec."Settlement Entry Type")
            {
                Caption = 'Settlement Entry Type';
            }

            // ── Document Reference ────────────────────────────────────────────
            field(documentNo; Rec."Document No.")
            {
                Caption = 'Document No.';
            }
            field(documentLineNo; Rec."Document Line No.")
            {
                Caption = 'Document Line No.';
            }

            // ── Customer / Vendor ─────────────────────────────────────────────
            field(cvNo; Rec."CV No.")
            {
                Caption = 'Customer/Vendor No.';
            }
            field(cvName; Rec."CV Name")
            {
                Caption = 'Customer/Vendor Name';
            }

            // ── Assignment & Settlement ───────────────────────────────────────
            field(assignmentId; Rec."Assignment ID")
            {
                Caption = 'Assignment ID';
            }
            field(settlementDate; Rec."Settlement Date")
            {
                Caption = 'Settlement Date';
            }
            field(settlementAmt; Rec."Settlement Amt (LCY)")
            {
                Caption = 'Settlement Amount (LCY)';
            }
            field(settlementAmtInclVat; Rec."Settlement Amt Incl. VAT (LCY)")
            {
                Caption = 'Settlement Amount Incl. VAT (LCY)';
            }
            field(cashDiscountAmt; Rec."Cash Discount Amt (LCY)")
            {
                Caption = 'Cash Discount Amount (LCY)';
            }
            field(cashDiscountAmtInclVat; Rec."Cash Discount Amt Incl. VAT (LCY)")
            {
                Caption = 'Cash Discount Amount Incl. VAT (LCY)';
            }
            field(originalLineAmt; Rec."Original Line Amt (LCY)")
            {
                Caption = 'Original Line Amount (LCY)';
            }
            field(originalLineAmtInclVat; Rec."Orig. Line Amt Incl. VAT (LCY)")
            {
                Caption = 'Original Line Amount Incl. VAT (LCY)';
            }
            field(nonDeductibleVatAmt; Rec."Non-Deductible VAT Amt (LCY)")
            {
                Caption = 'Non-Deductible VAT Amount (LCY)';
            }
            field(totalSettledAmtInclVat; Rec."Total Settled Amt Incl. VAT (LCY)")
            {
                Caption = 'Total Settled Amount Incl. VAT (LCY)';
            }
            field(totalSettledAmt; Rec."Total Settled Amt (LCY)")
            {
                Caption = 'Total Settled Amount (LCY)';
            }

            // ── Fully Settled Flags ───────────────────────────────────────────
            field(lineFullySettled; Rec."Line Fully Settled")
            {
                Caption = 'Line Fully Settled';
            }
            field(documentFullySettled; Rec."Document Fully Settled")
            {
                Caption = 'Document Fully Settled';
            }

            // ── Payment Reference ─────────────────────────────────────────────
            field(bankStatementDocumentNo; Rec."Bank Statement Document No.")
            {
                Caption = 'Bank Statement Document No.';
            }
            field(paymentReference; Rec."Payment Reference")
            {
                Caption = 'Payment Reference';
            }

            // ── Reversal ──────────────────────────────────────────────────────
            field(reversalEntry; Rec."Reversal Entry")
            {
                Caption = 'Reversal Entry';
            }
            field(originalEntryNo; Rec."Original Entry No.")
            {
                Caption = 'Original Entry No.';
            }
            field(reversed; Rec.Reversed)
            {
                Caption = 'Reversed';
            }
            field(reversalEntryNo; Rec."Reversal Entry No.")
            {
                Caption = 'Reversal Entry No.';
            }

            // ── G/L Account ───────────────────────────────────────────────────
            field(glAccountNo; Rec."G/L Account No.")
            {
                Caption = 'G/L Account No.';
            }
            field(glAccountName; Rec."G/L Account Name")
            {
                Caption = 'G/L Account Name';
            }

            // ── Dimensions ────────────────────────────────────────────────────
            // All 8 shortcut dimension codes are stored directly on the record —
            // no CalcFields or joins required; OData $filter on any of these is index-backed.
            field(globalDimension1Code; Rec."Global Dimension 1 Code")
            {
                Caption = 'Global Dimension 1 Code';
            }
            field(globalDimension2Code; Rec."Global Dimension 2 Code")
            {
                Caption = 'Global Dimension 2 Code';
            }
            field(shortcutDimension3Code; Rec."Shortcut Dimension 3 Code")
            {
                Caption = 'Shortcut Dimension 3 Code';
            }
            field(shortcutDimension4Code; Rec."Shortcut Dimension 4 Code")
            {
                Caption = 'Shortcut Dimension 4 Code';
            }
            field(shortcutDimension5Code; Rec."Shortcut Dimension 5 Code")
            {
                Caption = 'Shortcut Dimension 5 Code';
            }
            field(shortcutDimension6Code; Rec."Shortcut Dimension 6 Code")
            {
                Caption = 'Shortcut Dimension 6 Code';
            }
            field(shortcutDimension7Code; Rec."Shortcut Dimension 7 Code")
            {
                Caption = 'Shortcut Dimension 7 Code';
            }
            field(shortcutDimension8Code; Rec."Shortcut Dimension 8 Code")
            {
                Caption = 'Shortcut Dimension 8 Code';
            }
            // Dimension Set ID exposed for Power BI to join against the standard
            // Dimension Set Entry API if finer-grained dimension filtering is needed.
            field(dimensionSetId; Rec."Dimension Set ID")
            {
                Caption = 'Dimension Set ID';
            }

            // ── Grant Management ──────────────────────────────────────────────
            field(grantNumber; Rec."Grant Number")
            {
                Caption = 'Grant Number';
            }

            // ── Description ───────────────────────────────────────────────────
            field(description; Rec.Description)
            {
                Caption = 'Description';
            }

            // ── Audit Fields ──────────────────────────────────────────────────
            field(createdBy; Rec."Created By")
            {
                Caption = 'Created By';
            }
            field(createdDateTime; Rec."Created DateTime")
            {
                Caption = 'Created DateTime';
            }
        }
    }
}
