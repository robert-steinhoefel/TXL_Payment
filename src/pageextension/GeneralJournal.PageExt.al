namespace ALExtensions.ALExtensions;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.GeneralLedger.Ledger;

// TODO: Add OnBeforPOsting / OnAfterPosting event triggers and business functionality.

pageextension 51103 "GeneralJournal PageExt" extends "General Journal"
{
    layout
    {
        addbefore(Amount)
        {
            field("Reference Gen. Ledger Entry"; "Reference Gen. Ledger Entry")
            {
                // TODO: Add TableRelation and Lookup.
                ApplicationArea = All;
                Caption = 'Reference Gen. Ledger Entry';
                Visible = ShowColumns;
            }
            field("Edit Bank Transaction Data"; "Edit Bank Transaction Data")
            {
                ApplicationArea = All;
                Caption = 'Edit Bank Transaction Data';
                ToolTip = 'Check this box if you want to make changes to the bank transaction data used for cameralistics, e.g. set another bank transaction date or document number. If left false, the data from the reference G/L Entry will be used.';
                Visible = ShowColumns;
                trigger OnValidate()
                begin
                    if "Edit Bank Transaction Data" then
                        EditBankDetails := true
                    else
                        EditBankDetails := false;
                    CurrPage.Update();
                end;
            }
            field("Bank Transaction Date"; BankTransactionDate)
            {
                ApplicationArea = All;
                Caption = 'Bank Transaction Date';
                Visible = ShowColumns;
                Editable = EditBankDetails;
            }
            field("Bank Document No"; BankDocumentNo)
            {
                ApplicationArea = All;
                Caption = 'Bank Document No';
                Visible = ShowColumns;
                Editable = EditBankDetails;
            }
        }
        modify(CurrentJnlBatchName)
        {
            ApplicationArea = All;

            trigger OnAfterValidate()
            var
                JnlTemplates: Record "Gen. Journal Template";
                JnlTmplName: Code[10];
                JnlBatches: Record "Gen. Journal Batch";
            begin
                JnlBatches.Get(Rec."Journal Template Name", Rec."Journal Batch Name");
                if JnlBatches."Cameralistic Journal Batch" then
                    ShowColumns := true
                else
                    ShowColumns := false;
                CurrPage.Update();
            end;
        }
    }

    actions
    {

    }

    // FIXME: Does not work as designated, needs review. Intention is: Check if the current journal batch is marked with "Cameralistic Jnl Batch" = true. If so, show the additional column. If not, do not even show them.
    // TODO: There's currently no business functionality behind the additional fields in the journal batch.
    trigger OnOpenPage()
    var
        JnlTemplates: Record "Gen. Journal Template";
        JnlTmplName: Code[10];
        JnlBatches: Record "Gen. Journal Batch";
    begin
        JnlTemplates.SetRange(Type, Microsoft.Finance.GeneralLedger.Journal."Gen. Journal Template Type"::General);
        JnlTemplates.FindFirst();
        JnlBatches.Get(JnlTemplates.Name, CurrentJnlBatchName);
        if JnlBatches."Cameralistic Journal Batch" then
            ShowColumns := true
        else
            ShowColumns := false;
        // CurrPage.Update();
    end;

    var
        ShowColumns: Boolean;
        EditBankDetails: Boolean;
        "Edit Bank Transaction Data": Boolean;
        "Reference Gen. Ledger Entry": Integer;
        BankTransactionDate: Date;
        BankDocumentNo: Code[20];

}


