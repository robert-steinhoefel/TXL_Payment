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
        InvoiceLedgerEntry: Record "Vendor Ledger Entry";
        SetBankLedgerEntry: Codeunit "Bank Account Ledger Entries";
        InvLedgerEntryVariant: Variant;
    begin
        BankLedgerEntry := GetBankLedgerEntry(Rec);
        if (BankLedgerEntry."Entry No." = 0) then begin
            if not Rec.Unapplied = true then begin
                // If payment is has not been posted through bank account, we'll use the vendor's payment ledger entry data.
                // If posting is an un-application, these fields will remain empty - on purpose.
                BankLedgerEntry."Posting Date" := Rec."Posting Date";
                BankLedgerEntry."Document No." := Rec."Document No.";
            end;
        end;
        InvoiceLedgerEntry.Get(Rec."Vendor Ledger Entry No.");
        GetAndSetGLEntriesPaid(BankLedgerEntry, InvoiceLedgerEntry);
        InvLedgerEntryVariant := InvoiceLedgerEntry;
        if not Rec.Unapplied then
            SetBankLedgerEntry.GetAndProcessLedgerEntries(BankLedgerEntry, InvLedgerEntryVariant)
        else
            SetBankLedgerEntry.GetAndProcessLedgerEntries(BankLedgerEntry, true);
    end;

    local procedure GetAndSetGLEntriesPaid(var BankLedgerEntry: Record "Bank Account Ledger Entry"; var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        GLEntries: Record "G/L Entry";
    begin
        // ISSUE: What about partial payments to ledger entries?
        // ISSUE: When an invoice is being applied to two payments and one of those payments is cancelled, the entry is not modified.
        if not (BankLedgerEntry."Posting Date" = 0D) then begin
            VendorLedgerEntry.Paid := true;
            VendorLedgerEntry."Pmt Cancelled" := false;
        end else begin
            VendorLedgerEntry.Paid := false;
            VendorLedgerEntry."Pmt Cancelled" := true;
        end;
        VendorLedgerEntry."Bank Posting Date" := BankLedgerEntry."Posting Date";
        VendorLedgerEntry."Bank Document No." := BankLedgerEntry."Document No.";
        // TODO: Do we really need this if .. then here again? Should already be excluded with event subscriber...
        // if not ((VendorLedgerEntry."Document Type" = "Gen. Journal Document Type"::Payment) or (VendorLedgerEntry."Document Type" = "Gen. Journal Document Type"::Refund)) then
        VendorLedgerEntry.Modify();
        GLEntries.SetRange("Document No.", VendorLedgerEntry."Document No.");
        GLEntries.SetRange("Posting Date", VendorLedgerEntry."Posting Date");
        if not GLEntries.IsEmpty then begin
            GLEntries.ModifyAll("Bank Posting Date", BankLedgerEntry."Posting Date");
            GLEntries.ModifyAll("Bank Document No.", BankLedgerEntry."Document No.");
            if not (BankLedgerEntry."Posting Date" = 0D) then begin
                GLEntries.ModifyAll("CV Doc. Due Date", VendorLedgerEntry."Due Date");
                GLEntries.ModifyAll(Paid, true);
                GLEntries.ModifyAll("Pmt Cancelled", false);
            end else begin
                GLEntries.ModifyAll("CV Doc. Due Date", 0D);
                GLEntries.ModifyAll(Paid, false);
                GLEntries.ModifyAll("Pmt Cancelled", true);
            end;
        end;
    end;

    // Helper methods

    local procedure GetBankLedgerEntry(var DetailedVendorLedgEntry: Record "Detailed Vendor Ledg. Entry"): Record "Bank Account Ledger Entry"
    // ISSUE: Method needs testing.
    var
        DetailedPmtVendorLedgerEntry: Record "Detailed Vendor Ledg. Entry";
        VendorLederEntry: Record "Vendor Ledger Entry";
        BankLedgerEntry: Record "Bank Account Ledger Entry";
        ErrorTooManyRecords: Label 'Found %1 records of %2.';
    begin
        if VendorLederEntry.Get(DetailedVendorLedgEntry."Applied Vend. Ledger Entry No.") then begin
            // ISSUE: The DetailedPmtVendorLedgerEntry = DetailedVendorLedgerEntry.
            // something's rotten in the state of denmark
            //
            // DetailedPmtVendorLedgerEntry.SetRange("Vendor Ledger Entry No.", DetailedVendorLedgEntry."Applied Vend. Ledger Entry No.");

            // DetailedPmtVendorLedgerEntry.SetRange("Vendor Ledger Entry No.", DetailedVendorLedgEntry."Vendor Ledger Entry No.");
            // DetailedPmtVendorLedgerEntry.SetRange("Entry Type", "Detailed CV Ledger Entry Type"::Application);
            // DetailedPmtVendorLedgerEntry.SetRange(Unapplied, false);
            // DetailedPmtVendorLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Payment, "Gen. Journal Document Type"::Refund);
            // DetailedPmtVendorLedgerEntry.SetFilter("Initial Document Type", '%1|%2', "Gen. Journal Document Type"::Invoice, "Gen. Journal Document Type"::"Credit Memo");
            // DetailedPmtVendorLedgerEntry.SetFilter("Applied Vend. Ledger Entry No.", '<>%1', DetailedVendorLedgEntry."Vendor Ledger Entry No.");
            // DetailedPmtVendorLedgerEntry.SetFilter("Applied Vend. Ledger Entry No.", '%1', DetailedVendorLedgEntry."Applied Vend. Ledger Entry No.");
            // if DetailedPmtVendorLedgerEntry.Count() > 1 then
            // Error(StrSubstNo(ErrorTooManyRecords, Format(DetailedPmtVendorLedgerEntry.Count()), DetailedVendorLedgEntry.TableCaption()));
            // if DetailedPmtVendorLedgerEntry.FindFirst() then begin
            // BankLedgerEntry.SetRange("Transaction No.", DetailedPmtVendorLedgerEntry."Transaction No.");

            BankLedgerEntry.SetRange("Transaction No.", VendorLederEntry."Transaction No.");
            BankLedgerEntry.SetRange("Posting Date", DetailedVendorLedgEntry."Posting Date");
            BankLedgerEntry.SetRange("Document No.", DetailedVendorLedgEntry."Document No.");
            BankLedgerEntry.SetRange("Bal. Account No.", DetailedVendorLedgEntry."Vendor No.");
            BankLedgerEntry.SetRange("Amount (LCY)", (DetailedVendorLedgEntry."Amount (LCY)" * -1));
            if BankLedgerEntry.Count > 1 then
                Error(StrSubstNo(ErrorTooManyRecords, Format(BankLedgerEntry.Count()), BankLedgerEntry.TableCaption()));
            if BankLedgerEntry.FindFirst() then
                exit(BankLedgerEntry)
        end
        else begin
            Clear(BankLedgerEntry);
            exit(BankLedgerEntry);
        end;
    end;
}
