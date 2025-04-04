namespace P3.TXL.Payment.Vendor;

using Microsoft.Purchases.Payables;
using Microsoft.Bank.Ledger;
using P3.TXL.Payment.BankAccount;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Finance.ReceivablesPayables;

codeunit 51102 "Vendor Ledger Entries"
{
    TableNo = "Detailed Vendor Ledg. Entry";
    Permissions = tabledata "Bank Account Ledger Entry" = r,
                    tabledata "Detailed Vendor Ledg. Entry" = r,
                    tabledata "G/L Entry" = rm,
                    tabledata "Vendor Ledger Entry" = rm;

    trigger OnRun()
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
        VendorLedgerToModify, PaymentVendorLedgerEntry : Record "Vendor Ledger Entry";
        PaymentDetailedLedgerEntry: Record "Detailed Vendor Ledg. Entry";
        VendLedgEntryNo: Integer;
        SetBankLedgerEntry: Codeunit "Bank Account Ledger Entries";
        InvLedgerEntryVariant: Variant;
        ErrTooManyRecords: Label 'Too many %1 found to continue processing.';
        ErrNoRecords: Label 'No %1 found to continue processing.';
    begin
        VendorLedgerToModify.Get(Rec."Vendor Ledger Entry No.");
        if Rec."Vendor Ledger Entry No." = Rec."Applied Vend. Ledger Entry No." then begin
            // we'll enter this lopp if an application is started from the invoice-type vendor ledger entry
            // first: find the corresponding payment-type vendor ledger entry with the help of the counter-parted detailed vendor ledger entry.
            PaymentDetailedLedgerEntry.SetRange("Applied Vend. Ledger Entry No.", Rec."Applied Vend. Ledger Entry No.");
            PaymentDetailedLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
            PaymentDetailedLedgerEntry.SetRange(Unapplied, Rec.Unapplied);
            // TODO: Figure if this is only needed on unapplication or if this also works on application
            if Rec.Unapplied then
                PaymentDetailedLedgerEntry.SetFilter("Transaction No.", '<>%1', 0);
            PaymentDetailedLedgerEntry.SetFilter("Vendor Ledger Entry No.", '<>%1', Rec."Vendor Ledger Entry No.");
            PaymentDetailedLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund);
            if PaymentDetailedLedgerEntry.FindSet() then
                // check if we really do have multiple payment entries.
                repeat
                    if VendLedgEntryNo = 0 then
                        VendLedgEntryNo := PaymentDetailedLedgerEntry."Vendor Ledger Entry No.";
                    if (VendLedgEntryNo <> PaymentDetailedLedgerEntry."Vendor Ledger Entry No.") then
                        Error(StrSubstNo(ErrTooManyRecords, PaymentDetailedLedgerEntry.TableCaption()));
                until PaymentDetailedLedgerEntry.Next() = 0;
            if Rec.Unapplied and (PaymentDetailedLedgerEntry.Count = 0) then
                Error(StrSubstNo(ErrNoRecords, PaymentDetailedLedgerEntry.TableCaption()));
            // now we can GET the invoice-type entry:
            PaymentVendorLedgerEntry.Get(VendLedgEntryNo);
            // second, we'll find the originatig detailed vendor ledger entry for the payment:
            PaymentDetailedLedgerEntry.Reset();
            PaymentDetailedLedgerEntry.SetRange("Transaction No.", PaymentVendorLedgerEntry."Transaction No.");
            PaymentDetailedLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::"Initial Entry");
            PaymentDetailedLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund);
            PaymentDetailedLedgerEntry.SetRange(Unapplied, false);
            PaymentDetailedLedgerEntry.SetRange("Applied Vend. Ledger Entry No.", 0);
            PaymentDetailedLedgerEntry.FindFirst();
            // so at last, we can get the corresponding bank account ledger entry
            BankLedgerEntry := GetBankLedgerEntry(PaymentDetailedLedgerEntry, PaymentVendorLedgerEntry);
        end else begin
            // when application of ledger entries is started from the payment-type vendor ledger entry, we'll enter here.
            BankLedgerEntry := GetBankLedgerEntry(Rec, VendorLedgerToModify);
        end;

        if (BankLedgerEntry."Entry No." = 0) and not (Rec.Unapplied = true) then begin
            // If payment is has not been posted through bank account, we'll use the vendor's payment ledger entry data.
            // If posting is an un-application, these fields will and should remain empty.
            BankLedgerEntry."Posting Date" := Rec."Posting Date";
            BankLedgerEntry."Document No." := Rec."Document No.";
        end;

        GetAndSetPaymentData(BankLedgerEntry, VendorLedgerToModify, Rec.Unapplied);
        InvLedgerEntryVariant := VendorLedgerToModify;
        if not Rec.Unapplied then
            SetBankLedgerEntry.GetAndProcessLedgerEntries(BankLedgerEntry, InvLedgerEntryVariant)
        else
            SetBankLedgerEntry.UnApplyLedgerEntries(BankLedgerEntry, true);
    end;

    local procedure GetAndSetPaymentData(var BankLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry"; var Unapplied: Boolean)
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
            DocumentNo := '';
            CVDocDueDate := 0D;
        end else begin
            Paid := true;
            Cancelled := false;
            PostingDate := BankLedgerEntry."Posting Date";
            DocumentNo := BankLedgerEntry."Document No.";
            CVDocDueDate := VendorLedgerEntry."Due Date";
        end;
        GLEntries.SetRange("Document No.", VendorLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", VendorLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll("Bank Posting Date", PostingDate);
            GLEntries.ModifyAll("Bank Document No.", DocumentNo);
            GLEntries.ModifyAll("CV Doc. Due Date", CVDocDueDate);
            GLEntries.ModifyAll(Paid, Paid);
            GLEntries.ModifyAll("Pmt Cancelled", Cancelled);
        end;
        VendorLedgerEntry.Paid := Paid;
        VendorLedgerEntry."Pmt Cancelled" := Cancelled;
        VendorLedgerEntry."Bank Posting Date" := PostingDate;
        VendorLedgerEntry."Bank Document No." := DocumentNo;
        VendorLedgerEntry.Modify();
    end;

    // Helper methods

    local procedure GetBankLedgerEntry(var DetailedVendorLedgEntry: Record "Detailed Vendor Ledg. Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry"): Record "Bank Account Ledger Entry"
    // ISSUE: Method needs testing.
    var
        BankLedgerEntry: Record "Bank Account Ledger Entry";
        ErrorTooManyRecords: Label 'Found %1 records of %2.';
        TheOtherVendLedgEntr: Record "Vendor Ledger Entry";
    begin
        if (DetailedVendorLedgEntry."Vendor Ledger Entry No." <> DetailedVendorLedgEntry."Applied Vend. Ledger Entry No.")
                and (DetailedVendorLedgEntry."Applied Vend. Ledger Entry No." <> 0) then begin
            TheOtherVendLedgEntr.Get(DetailedVendorLedgEntry."Applied Vend. Ledger Entry No.");
            BankLedgerEntry.SetRange("Transaction No.", TheOtherVendLedgEntr."Transaction No.");
            // Changed b/c makes sense, taken from CustLedger Entry:
            BankLedgerEntry.SetRange("Posting Date", DetailedVendorLedgEntry."Posting Date");
        end else begin
            BankLedgerEntry.SetRange("Transaction No.", VendorLedgerEntry."Transaction No.");
            // Changed b/c makes sense, taken from CustLedger Entry:
            BankLedgerEntry.SetRange("Posting Date", DetailedVendorLedgEntry."Posting Date");
        end;
        BankLedgerEntry.SetRange("Document No.", DetailedVendorLedgEntry."Document No.");
        BankLedgerEntry.SetRange("Bal. Account No.", DetailedVendorLedgEntry."Vendor No.");
        if not DetailedVendorLedgEntry.Unapplied then
            BankLedgerEntry.SetRange("Amount (LCY)", (DetailedVendorLedgEntry."Amount (LCY)" * -1))
        else
            BankLedgerEntry.SetRange("Amount (LCY)", (DetailedVendorLedgEntry."Amount (LCY)"));
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
