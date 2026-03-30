namespace P3.TXL.Payment.Settlement;

// Temporary buffer table for the Payment Allocation page (page 51101).
// Populated per-session by SettlementEntryMgt.HandlePartialPayment from
// Sales Invoice Lines; never persisted to the database.
table 51107 "Pmt. Alloc. Line Buffer"
{
    Caption = 'Payment Allocation Line Buffer';
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        // Part of the composite PK so Pmt. Alloc. Context can store allocations for multiple
        // invoices simultaneously (e.g. batch with several partial payments, or one payment
        // applied to multiple invoices at once). 0 in the page's own temporary buffer.
        field(1; "Inv. CLE Entry No."; Integer)
        {
            Caption = 'Invoice CLE Entry No.';
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(4; "G/L Account No."; Code[20])
        {
            Caption = 'G/L Account No.';
        }
        field(5; "Original Amt (LCY)"; Decimal)
        {
            Caption = 'Original Amount (LCY)';
            AutoFormatType = 1;
        }
        field(6; "Orig. Amt Incl. VAT (LCY)"; Decimal)
        {
            Caption = 'Original Amount Incl. VAT (LCY)';
            AutoFormatType = 1;
        }
        // Populated in Story 3.2 (already-paid partial payments).
        // Always 0 for Story 3.1 first partial payment scenarios.
        field(7; "Already Settled Amt (LCY)"; Decimal)
        {
            Caption = 'Already Settled Amount (LCY)';
            AutoFormatType = 1;
        }
        // The editable field: user enters how much of the payment applies to this line.
        // Amounts are in incl. VAT terms to match the bank transfer amount.
        field(8; "Alloc. Amt Incl. VAT (LCY)"; Decimal)
        {
            Caption = 'Allocation Amount Incl. VAT (LCY)';
            AutoFormatType = 1;
        }
        field(9; "Dimension Set ID"; Integer)
        {
            Caption = 'Dimension Set ID';
        }
        field(10; "Global Dimension 1 Code"; Code[20])
        {
            Caption = 'Global Dimension 1 Code';
            CaptionClass = '1,1,1';
        }
        field(11; "Global Dimension 2 Code"; Code[20])
        {
            Caption = 'Global Dimension 2 Code';
            CaptionClass = '1,1,2';
        }
    }

    keys
    {
        key(PK; "Inv. CLE Entry No.", "Line No.")
        {
            Clustered = true;
        }
    }
}
