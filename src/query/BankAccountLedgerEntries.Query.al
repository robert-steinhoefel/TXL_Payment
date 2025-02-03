namespace ALExtensions.ALExtensions;

using Microsoft.Bank.Ledger;

query 51100 "Bank Account Ledger Entries"
{
    Caption = 'Bank Account Ledger Entries';
    QueryType = API;
    EntitySetName = 'CameralisticBankAccountLedgerEntries';
    EntityName = 'CameralisticBankAccountLedgerEntry';
    APIPublisher = 'P3';
    APIVersion = 'v1.0';
    APIGroup = 'CameralisticLedgerEntries';

    elements
    {
        dataitem(BankAccountLedgerEntry; "Bank Account Ledger Entry")
        {
            column(BankAccountNo; "Bank Account No.")
            {
            }
            column(AmountLCY; "Amount (LCY)")
            {
            }
            column(PostingDate; "Posting Date")
            {
            }
            column(StatementNo; "Statement No.")
            {
            }
            column(BalAccountType; "Bal. Account Type")
            {
            }
            column(BalAccountNo; "Bal. Account No.")
            {
            }
            column(CVDocType; "CV Doc Type")
            {
            }
            column(CVDocNo; "CV Doc. No.")
            {
            }
            column(CVDocDueDate; "CV Doc. Due Date")
            {
            }
            column(CVGlobalDimension1Code; "CV Global Dimension 1 Code")
            {
            }
            column(CVGlobalDimension2Code; "CV Global Dimension 2 Code")
            {
            }
            column(CVDimensionSetID; "CV Dimension Set ID")
            {
            }
            column(LedgerEntryType; "Ledger Entry Type")
            {
            }
        }
    }

    trigger OnBeforeOpen()
    begin

    end;
}
