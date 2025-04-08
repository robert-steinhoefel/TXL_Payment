namespace P3.TXL.Payment.Customer;

using P3.TXL.Payment.BankAccount;
using Microsoft.Sales.Receivables;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Bank.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;

codeunit 51103 "Customer Ledger Entries"
{
    TableNo = "Detailed Cust. Ledg. Entry";
    Permissions = tabledata "Bank Account Ledger Entry" = r,
                    tabledata "Detailed Cust. Ledg. Entry" = r,
                    tabledata "G/L Entry" = rm,
                    tabledata "Cust. Ledger Entry" = rm;

    trigger OnRun()
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
        InvoiceLedgerEntry: Record "Cust. Ledger Entry";
        CustomerLedgerToModify, PaymentCustomerLedgerEntry : Record "Cust. Ledger Entry";
        PaymentDetailedLedgerEntry: Record "Detailed Cust. Ledg. Entry";
        CustLedgEntryNo: Integer;
        SetBankLedgerEntry: Codeunit "Bank Account Ledger Entries";
        InvLedgerEntryVariant: Variant;
        ErrTooManyRecords: Label 'Too many %1 found to continue processing.';
        ErrNoRecords: Label 'No %1 found to continue processing.';
    begin
        CustomerLedgerToModify.Get(Rec."Cust. Ledger Entry No.");
        if Rec."Cust. Ledger Entry No." = Rec."Applied Cust. Ledger Entry No." then begin
            // we'll enter this lopp if an application is started from the invoice-type customer ledger entry
            // first: find the corresponding payment-type customer ledger entry with the help of the counter-parted detailed customer ledger entry.
            PaymentDetailedLedgerEntry.SetRange("Applied Cust. Ledger Entry No.", Rec."Applied Cust. Ledger Entry No.");
            PaymentDetailedLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
            PaymentDetailedLedgerEntry.SetRange(Unapplied, Rec.Unapplied);
            // TODO: Figure if this is only needed on unapplication or if this also works on application
            if Rec.Unapplied then
                PaymentDetailedLedgerEntry.SetFilter("Transaction No.", '<>%1', 0);
            PaymentDetailedLedgerEntry.SetFilter("Cust. Ledger Entry No.", '<>%1', Rec."Cust. Ledger Entry No.");
            PaymentDetailedLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund);

            if PaymentDetailedLedgerEntry.FindSet() then
                // check if we really do have multiple payment entries.
                repeat
                    if CustLedgEntryNo = 0 then
                        CustLedgEntryNo := PaymentDetailedLedgerEntry."Cust. Ledger Entry No.";
                    if (CustLedgEntryNo <> PaymentDetailedLedgerEntry."Cust. Ledger Entry No.") then
                        Error(StrSubstNo(ErrTooManyRecords, PaymentDetailedLedgerEntry.TableCaption()));
                until PaymentDetailedLedgerEntry.Next() = 0;

            if Rec.Unapplied and (PaymentDetailedLedgerEntry.Count = 0) then
                Error(StrSubstNo(ErrNoRecords, PaymentDetailedLedgerEntry.TableCaption()));
            // now we can GET the invoice-type entry:
            PaymentCustomerLedgerEntry.Get(CustLedgEntryNo);
            // second, we'll find the originatig detailed customer ledger entry for the payment:
            PaymentDetailedLedgerEntry.Reset();
            PaymentDetailedLedgerEntry.SetRange("Transaction No.", PaymentCustomerLedgerEntry."Transaction No.");
            PaymentDetailedLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::"Initial Entry");
            PaymentDetailedLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund);
            PaymentDetailedLedgerEntry.SetRange(Unapplied, false);
            PaymentDetailedLedgerEntry.SetRange("Applied Cust. Ledger Entry No.", 0);
            PaymentDetailedLedgerEntry.FindFirst();
            // so at last, we can get the corresponding bank account ledger entry
            BankLedgerEntry := GetBankLedgerEntry(PaymentDetailedLedgerEntry, PaymentCustomerLedgerEntry);
        end else begin
            // when application of ledger entries is started from the payment-type vendor ledger entry, we'll enter here.
            // TODO: The bank ledger Entry is not found / modified in this section. Something still seems to be different than with vendors
            BankLedgerEntry := GetBankLedgerEntry(Rec, CustomerLedgerToModify);
        end;



        if (BankLedgerEntry."Entry No." = 0) and not (Rec.Unapplied = true) then begin
            // If payment is has not been posted through bank account, we'll use the vendor's payment ledger entry data.
            // If posting is an un-application, these fields will and should remain empty.
            BankLedgerEntry."Posting Date" := Rec."Posting Date";
            BankLedgerEntry."Document No." := Rec."Document No.";
        end;

        GetAndSetPaymentData(BankLedgerEntry, CustomerLedgerToModify, Rec.Unapplied);
        InvLedgerEntryVariant := CustomerLedgerToModify;
        if not Rec.Unapplied then
            SetBankLedgerEntry.GetAndProcessLedgerEntries(BankLedgerEntry, InvLedgerEntryVariant)
        else
            SetBankLedgerEntry.UnApplyLedgerEntries(BankLedgerEntry, true);
    end;

    local procedure GetAndSetPaymentData(var BankLedgerEntry: Record "Bank Account Ledger Entry"; var CustomerLedgerEntry: Record "Cust. Ledger Entry"; var Unapplied: Boolean)
    var
        GLEntries: Record "G/L Entry";
        PostingDate, CVDocDueDate : Date;
        Paid, Cancelled : Boolean;
        DocumentNo: Code[20];
    begin
        // ISSUE: What about partial payments to ledger entries?
        // ISSUE: When an invoice is being applied to two payments and one of those payments is cancelled, the entry is not modified.
        if Unapplied then begin
            Paid := false;
            Cancelled := true;
            // Using vars to not change the Bank Ledger Entry since it's needed again later.
            PostingDate := 0D;
            CVDocDueDate := 0D;
            DocumentNo := '';
        end else begin
            Paid := true;
            Cancelled := false;
            PostingDate := BankLedgerEntry."Posting Date";
            DocumentNo := BankLedgerEntry."Document No.";
            CVDocDueDate := CustomerLedgerEntry."Due Date";
        end;
        GLEntries.SetRange("Document No.", CustomerLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", CustomerLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll("Bank Posting Date", PostingDate);
            GLEntries.ModifyAll("Bank Document No.", DocumentNo);
            GLEntries.ModifyAll("CV Doc. Due Date", CVDocDueDate);
            GLEntries.ModifyAll(Paid, Paid);
            GLEntries.ModifyAll("Pmt Cancelled", Cancelled);
        end;
        CustomerLedgerEntry.Paid := Paid;
        CustomerLedgerEntry."Pmt Cancelled" := Cancelled;
        CustomerLedgerEntry."Bank Posting Date" := PostingDate;
        CustomerLedgerEntry."Bank Document No." := DocumentNo;
        CustomerLedgerEntry.Modify();
    end;

    // Helper methods

    local procedure GetBankLedgerEntry(var DetailedCustomerLedgEntry: Record "Detailed Cust. Ledg. Entry"; var CustomerLedgerEntry: Record "Cust. Ledger Entry"): Record "Bank Account Ledger Entry"
    // ISSUE: Method needs testing.
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
        ErrorTooManyRecords: Label 'Found %1 records of %2.';
        TheOtherVendLedgEntr: Record "Cust. Ledger Entry";
    begin
        if (DetailedCustomerLedgEntry."Cust. Ledger Entry No." <> DetailedCustomerLedgEntry."Applied Cust. Ledger Entry No.")
                and (DetailedCustomerLedgEntry."Applied Cust. Ledger Entry No." <> 0) then begin
            TheOtherVendLedgEntr.Get(DetailedCustomerLedgEntry."Applied Cust. Ledger Entry No.");
            BankLedgerEntry.SetRange("Transaction No.", TheOtherVendLedgEntr."Transaction No.");
            BankLedgerEntry.SetRange("Posting Date", TheOtherVendLedgEntr."Posting Date");
        end else begin
            BankLedgerEntry.SetRange("Transaction No.", CustomerLedgerEntry."Transaction No.");
            BankLedgerEntry.SetRange("Posting Date", DetailedCustomerLedgEntry."Posting Date");
        end;
        BankLedgerEntry.SetRange("Document No.", DetailedCustomerLedgEntry."Document No.");
        BankLedgerEntry.SetRange("Bal. Account No.", DetailedCustomerLedgEntry."Customer No.");
        if not DetailedCustomerLedgEntry.Unapplied then
            BankLedgerEntry.SetRange("Amount (LCY)", (DetailedCustomerLedgEntry."Amount (LCY)") * -1)
        else
            BankLedgerEntry.SetRange("Amount (LCY)", (DetailedCustomerLedgEntry."Amount (LCY)"));
        if BankLedgerEntry.Count > 1 then
            Error(StrSubstNo(ErrorTooManyRecords, Format(BankLedgerEntry.Count()), BankLedgerEntry.TableCaption()));
        if BankLedgerEntry.FindFirst() then
            exit(BankLedgerEntry)
        else begin
            Clear(BankLedgerEntry);
            exit(BankLedgerEntry);
        end;
    end;
}
