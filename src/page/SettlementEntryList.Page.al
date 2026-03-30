namespace P3.TXL.Payment.Settlement;

using Microsoft.Finance.GeneralLedger.Journal;

// Story 1.5: Settlement Entry List page.
// Read-only audit/inspection page for Settlement Entries (table 51106).
// Entries are created exclusively by SettlementEntryMgt (Epic 2/3) — no manual insert/modify/delete.
// Referenced as DrillDownPageId and LookupPageId on the Settlement Entry table.
page 51100 "Settlement Entry List"
{
    Caption = 'Settlement Entry List';
    PageType = List;
    SourceTable = "Settlement Entry";
    ApplicationArea = All;
    UsageCategory = History;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                // ── Identity ────────────────────────────────────────────────
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique sequential entry number.';
                    Visible = false;
                }
                field("Settlement Entry Type"; Rec."Settlement Entry Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the entry type. Normal = standard settlement; Unallocated = payment amount not yet linked to an invoice line.';
                }
                field("Transaction Type"; Rec."Transaction Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this entry originates from a Sales or Purchase transaction.';
                }
                field("Document Type"; Rec."Document Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document type (Invoice or Credit Memo) of the settled document.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the document number of the settled invoice or credit memo.';
                }
                field("Document Line No."; Rec."Document Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the line number within the settled document.';
                    Visible = false;
                }

                // ── Customer / Vendor ────────────────────────────────────────
                field("CV No."; Rec."CV No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer or vendor number.';
                }
                field("CV Name"; Rec."CV Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer or vendor name as it was at the time of settlement.';
                }

                // ── Settlement Amounts ───────────────────────────────────────
                field("Settlement Date"; Rec."Settlement Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date on which the settlement was recorded.';
                }
                field("Settlement Amt (LCY)"; Rec."Settlement Amt (LCY)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the net settled amount in local currency. Reversal entries carry opposite signs.';
                }
                field("Settlement Amt Incl. VAT (LCY)"; Rec."Settlement Amt Incl. VAT (LCY)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the settled amount including VAT in local currency.';
                    Visible = false;
                }
                field("Cash Discount Amt (LCY)"; Rec."Cash Discount Amt (LCY)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies any cash discount amount (excl. VAT) granted at the time of settlement.';
                    Visible = false;
                }

                // ── Original Line Amounts ────────────────────────────────────
                // Snapshots from the source document line at settlement creation time.
                // Allow direct comparison of original billed amounts vs. settled amounts.
                field("Original Line Amt (LCY)"; Rec."Original Line Amt (LCY)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the original invoice/credit memo line amount (excl. VAT) at the time of settlement.';
                    Visible = true;
                }
                field("Orig. Line Amt Incl. VAT (LCY)"; Rec."Orig. Line Amt Incl. VAT (LCY)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the original invoice/credit memo line amount (incl. VAT) at the time of settlement.';
                    Visible = true;
                }
                field("Non-Deductible VAT Amt (LCY)"; Rec."Non-Deductible VAT Amt (LCY)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the non-deductible VAT amount for this invoice line at the time of settlement.';
                    Visible = true;
                }

                // ── Assignment ───────────────────────────────────────────────
                field("Assignment ID"; Rec."Assignment ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the assignment ID grouping all settlements (payments, credit memos, reversals) for the same invoice.';
                    Visible = false;
                }

                // ── Payment Reference ────────────────────────────────────────
                field("Bank Statement Document No."; Rec."Bank Statement Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the bank statement document number that triggered this settlement.';
                }
                field("Payment Reference"; Rec."Payment Reference")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the payment reference text from the bank statement.';
                    Visible = false;
                }

                // ── Reversal ─────────────────────────────────────────────────
                field("Reversal Entry"; Rec."Reversal Entry")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this entry is a reversal of a previous settlement.';
                }
                field(Reversed; Rec.Reversed)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this entry has been reversed by a later entry.';
                }

                // ── Dimensions ───────────────────────────────────────────────
                field("Global Dimension 1 Code"; Rec."Global Dimension 1 Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Global Dimension 1 code (e.g. cost center).';
                    Visible = false;
                }
                field("Global Dimension 2 Code"; Rec."Global Dimension 2 Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the value of the Global Dimension 2 code.';
                    Visible = false;
                }

                // ── G/L Account ──────────────────────────────────────────────
                field("G/L Account No."; Rec."G/L Account No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the G/L account number associated with this settlement.';
                    Visible = false;
                }
                field("G/L Account Name"; Rec."G/L Account Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the G/L account name as it was at the time of settlement.';
                    Visible = false;
                }

                // ── Grant Management ─────────────────────────────────────────
                field("Grant Number"; Rec."Grant Number")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the grant number associated with this settlement.';
                    Visible = false;
                }

                // ── Description & Audit ──────────────────────────────────────
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a description for this settlement entry.';
                }
                field("Created By"; Rec."Created By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user who created this settlement entry.';
                    Visible = false;
                }
                field("Created DateTime"; Rec."Created DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time when this settlement entry was created.';
                    Visible = false;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Ascending(false);
    end;
}
