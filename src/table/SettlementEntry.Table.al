namespace P3.TXL.Payment.Settlement;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Sales.Customer;
using Microsoft.Purchases.Vendor;
using System.Security.AccessControl;

table 51106 "Settlement Entry"
{
    Caption = 'Settlement Entry';
    DataClassification = CustomerContent;
    DrillDownPageId = "Settlement Entry List";
    LookupPageId = "Settlement Entry List";

    fields
    {
        // ── Primary Key ───────────────────────────────────────────────────────
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }

        // ── Source Classification ─────────────────────────────────────────────
        // Transaction Type (Sales/Purchase) + Document Type (Invoice/Credit Memo)
        // fully identify the origin of every Settlement Entry.
        // Document Type reuses the standard BC Gen. Journal Document Type enum —
        // no custom enum needed.
        field(10; "Transaction Type"; Enum "Settlement Transaction Type")
        {
            Caption = 'Transaction Type';
        }
        field(11; "Document Type"; Enum "Gen. Journal Document Type")
        {
            Caption = 'Document Type';
        }

        // ── Document Reference ────────────────────────────────────────────────
        field(12; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(13; "Document Line No."; Integer)
        {
            Caption = 'Document Line No.';
        }

        // ── Assignment & Settlement ───────────────────────────────────────────
        // Assignment ID groups all Settlement Entries belonging to the same invoice,
        // enabling Power BI to aggregate payments, credit memos, and reversals per invoice.
        // Format: {CustomerNo}-{YYMMDD}-{SeqNo}, e.g. CUST001-260312-001
        field(20; "Assignment ID"; Code[50])
        {
            Caption = 'Assignment ID';
        }
        field(21; "Settlement Date"; Date)
        {
            Caption = 'Settlement Date';
        }
        field(22; "Settlement Amt (LCY)"; Decimal)
        {
            Caption = 'Settlement Amount (LCY)';
            AutoFormatType = 1;
        }
        field(23; "Settlement Amt Incl. VAT (LCY)"; Decimal)
        {
            Caption = 'Settlement Amount (LCY) including VAT';
            AutoFormatType = 1;
        }
        field(24; "Cash Discount Amt (LCY)"; Decimal)
        {
            Caption = 'Cash Discount Amount (LCY)';
            AutoFormatType = 1;
        }

        // ── Original Line Amounts ─────────────────────────────────────────────
        // Snapshot of the source invoice/credit memo line amounts at the time the
        // Settlement Entry is created. Stored here so reporting can compare what
        // was originally billed against what was actually settled, without joining
        // back to the posted document line (which may be archived or unavailable).
        // Populated by SettlementEntryMgt (Epic 2/3) from the posted document line.
        field(25; "Original Line Amt (LCY)"; Decimal)
        {
            Caption = 'Original Line Amount (LCY)';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
        field(26; "Orig. Line Amt Incl. VAT (LCY)"; Decimal)
        {
            Caption = 'Original Line Amount Incl. VAT (LCY)';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }
        field(27; "Non-Deductible VAT Amt (LCY)"; Decimal)
        {
            Caption = 'Non-Deductible VAT Amount (LCY)';
            DataClassification = CustomerContent;
            AutoFormatType = 1;
        }

        // ── Payment Reference ─────────────────────────────────────────────────
        field(30; "Bank Statement Document No."; Code[20])
        {
            Caption = 'Bank Statement Document No.';
        }
        field(31; "Payment Reference"; Text[100])
        {
            Caption = 'Payment Reference';
        }

        // ── Reversal ──────────────────────────────────────────────────────────
        // Reversals create new entries with opposite signs (Reversal Entry = true)
        // instead of deleting original entries, preserving the full audit trail.
        field(40; "Reversal Entry"; Boolean)
        {
            Caption = 'Reversal Entry';
        }
        field(41; "Original Entry No."; Integer)
        {
            Caption = 'Original Entry No.';
            TableRelation = "Settlement Entry"."Entry No.";
        }
        field(42; Reversed; Boolean)
        {
            Caption = 'Reversed';
        }
        field(43; "Reversal Entry No."; Integer)
        {
            Caption = 'Reversal Entry No.';
            TableRelation = "Settlement Entry"."Entry No.";
        }

        // ── Customer / Vendor ─────────────────────────────────────────────────
        // "CV" prefix (Customer/Vendor) matches the naming convention used throughout
        // this extension (CV Doc. No., CV Doc. Due Date, etc.).
        // TableRelation is conditional on Transaction Type; populated as a snapshot
        // at entry creation time by SettlementEntryMgt (name does not update on rename).
        field(50; "CV No."; Code[20])
        {
            Caption = 'Customer/Vendor No.';
            TableRelation = if ("Transaction Type" = const(Sales)) Customer."No."
                            else if ("Transaction Type" = const(Purchase)) Vendor."No.";
        }
        field(51; "CV Name"; Text[100])
        {
            Caption = 'Customer/Vendor Name';
        }

        // ── Dimensions ────────────────────────────────────────────────────────
        // All 8 shortcut dimension codes are stored directly to avoid joins in
        // Power BI and to enable indexed reporting per dimension + date.
        // Populated by SettlementEntryMgt using DimMgt.GetShortcutDimensions().
        field(60; "Global Dimension 1 Code"; Code[20])
        {
            Caption = 'Global Dimension 1 Code';
            CaptionClass = '1,1,1';
            TableRelation = "Dimension Value".Code where("Global Dimension No." = const(1));
        }
        field(61; "Global Dimension 2 Code"; Code[20])
        {
            Caption = 'Global Dimension 2 Code';
            CaptionClass = '1,1,2';
            TableRelation = "Dimension Value".Code where("Global Dimension No." = const(2));
        }
        field(62; "Shortcut Dimension 3 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 3 Code';
            CaptionClass = '1,2,3';
        }
        field(63; "Shortcut Dimension 4 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 4 Code';
            CaptionClass = '1,2,4';
        }
        field(64; "Shortcut Dimension 5 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 5 Code';
            CaptionClass = '1,2,5';
        }
        field(65; "Shortcut Dimension 6 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 6 Code';
            CaptionClass = '1,2,6';
        }
        field(66; "Shortcut Dimension 7 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 7 Code';
            CaptionClass = '1,2,7';
        }
        field(67; "Shortcut Dimension 8 Code"; Code[20])
        {
            Caption = 'Shortcut Dimension 8 Code';
            CaptionClass = '1,2,8';
        }
        field(68; "Dimension Set ID"; Integer)
        {
            Caption = 'Dimension Set ID';
            TableRelation = "Dimension Set Entry";
        }

        // ── G/L Account ───────────────────────────────────────────────────────
        field(80; "G/L Account No."; Code[20])
        {
            Caption = 'G/L Account No.';
            TableRelation = "G/L Account";
        }
        field(81; "G/L Account Name"; Text[100])
        {
            Caption = 'G/L Account Name';
        }

        // ── Grant Management ──────────────────────────────────────────────────
        field(90; "Grant Number"; Code[20])
        {
            Caption = 'Grant Number';
        }

        // ── Description ───────────────────────────────────────────────────────
        field(100; Description; Text[100])
        {
            Caption = 'Description';
        }

        // ── Audit Fields ──────────────────────────────────────────────────────
        field(110; "Created By"; Code[50])
        {
            Caption = 'Created By';
            TableRelation = User."User Name";
            DataClassification = EndUserIdentifiableInformation;
        }
        field(111; "Created DateTime"; DateTime)
        {
            Caption = 'Created DateTime';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(DocNoLineNo; "Document Type", "Transaction Type", "Document No.", "Document Line No.")
        {
            // Main lookup: find all settlements for a given invoice/cr.memo line.
        }
        key(AssignmentID; "Assignment ID")
        {
            // Group all payments, credit memos, and reversals per invoice.
        }
        key(CustomerDate; "CV No.", "Settlement Date")
        {
            // Reporting: settlements per customer over time.
        }
        key(DimensionDate; "Global Dimension 1 Code", "Settlement Date")
        {
            // Reporting: settlements per cost center / department over time.
        }
        key(BankDoc; "Bank Statement Document No.")
        {
            // Bank reconciliation: find settlement by bank statement line.
        }
    }

    fieldgroups
    {
        fieldgroup(DropDown; "Entry No.", "Document No.", "Document Line No.", "Settlement Date", "Settlement Amt (LCY)") { }
    }
}
