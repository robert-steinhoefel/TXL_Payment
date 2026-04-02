namespace P3.TXL.Payment.Settlement;

using Microsoft.Sales.Customer;
using Microsoft.Sales.History;
using Microsoft.Sales.Receivables;

// Story 3.1: Manual payment allocation page for partial payments.
// Opened modally by SettlementEntryMgt.HandlePartialPayment when a payment
// does not fully settle an invoice (InvoiceCLE."Remaining Amount" <> 0).
//
// The page is populated from Sales Invoice Lines of the invoice being partially
// paid. The user distributes the received payment amount (incl. VAT) across
// invoice lines. On Apply, SettlementEntryMgt reads the buffer via
// GetAllocationLines() and creates Settlement Entries. On Cancel, the caller
// throws an Error() which rolls back the entire application transaction.
//
// CANCEL BEHAVIOUR (see Asana discussion task):
//   Current assumption: Cancel = Error() in caller = full rollback.
//   No payment is applied to the customer ledger entry.
page 51101 "Payment Allocation"
{
    Caption = 'Manual Payment Allocation';
    PageType = Worksheet;
    SourceTable = "Pmt. Alloc. Line Buffer";
    SourceTableTemporary = true;
    ApplicationArea = All;
    Editable = true;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            // ── Payment summary header ─────────────────────────────────────────
            group(PaymentSummary)
            {
                Caption = 'Payment Details';

                field(CustomerNo; CustomerNo)
                {
                    ApplicationArea = All;
                    Caption = 'Customer No.';
                    ToolTip = 'Specifies the customer number for the invoice being partially paid.';
                    Editable = false;
                }
                field(CustomerName; CustomerName)
                {
                    ApplicationArea = All;
                    Caption = 'Customer Name';
                    ToolTip = 'Specifies the customer name.';
                    Editable = false;
                }
                field(InvoiceDocNo; InvoiceDocNo)
                {
                    ApplicationArea = All;
                    Caption = 'Invoice No.';
                    ToolTip = 'Specifies the invoice document number being partially settled.';
                    Editable = false;
                }
                field(ApplicationAmtLCY; ApplicationAmtLCY)
                {
                    ApplicationArea = All;
                    Caption = 'Payment Amount (LCY)';
                    ToolTip = 'Specifies the total payment amount received (incl. VAT). This is the amount to distribute across invoice lines.';
                    Editable = false;
                    AutoFormatType = 1;
                }
                field(TotalAllocated; CalcTotalAllocated())
                {
                    ApplicationArea = All;
                    Caption = 'Total Allocated (LCY)';
                    ToolTip = 'Specifies the sum of all allocation amounts entered so far.';
                    Editable = false;
                    AutoFormatType = 1;
                }
                field(RemainingToAllocate; ApplicationAmtLCY - CalcTotalAllocated())
                {
                    ApplicationArea = All;
                    Caption = 'Remaining to Allocate (LCY)';
                    ToolTip = 'Specifies how much of the payment amount still needs to be allocated. Must be 0 before applying.';
                    Editable = false;
                    AutoFormatType = 1;
                    Style = Attention;
                    StyleExpr = RemainingNonZero;
                }
            }

            // ── Invoice lines ──────────────────────────────────────────────────
            repeater(Lines)
            {
                field("Line No."; Rec."Line No.")
                {
                    ApplicationArea = All;
                    Caption = 'Line No.';
                    Editable = false;
                    ToolTip = 'Specifies the invoice line number.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    Caption = 'Description';
                    Editable = false;
                    ToolTip = 'Specifies the description from the invoice line.';
                }
                field("G/L Account No."; Rec."G/L Account No.")
                {
                    ApplicationArea = All;
                    Caption = 'G/L Account No.';
                    Editable = false;
                    ToolTip = 'Specifies the G/L account number from the invoice line.';
                }
                field("Original Amt (LCY)"; Rec."Original Amt (LCY)")
                {
                    ApplicationArea = All;
                    Caption = 'Original Amount (LCY)';
                    Editable = false;
                    ToolTip = 'Specifies the original invoice line amount excl. VAT.';
                }
                field("Orig. Amt Incl. VAT (LCY)"; Rec."Orig. Amt Incl. VAT (LCY)")
                {
                    ApplicationArea = All;
                    Caption = 'Original Amount Incl. VAT (LCY)';
                    Editable = false;
                    ToolTip = 'Specifies the original invoice line amount incl. VAT.';
                }
                field("Already Settled Amt (LCY)"; Rec."Already Settled Amt (LCY)")
                {
                    ApplicationArea = All;
                    Caption = 'Already Settled (LCY)';
                    Editable = false;
                    ToolTip = 'Specifies the amount already settled by previous partial payments on this line. Populated in Story 3.2.';
                }
                field("Alloc. Amt Incl. VAT (LCY)"; Rec."Alloc. Amt Incl. VAT (LCY)")
                {
                    ApplicationArea = All;
                    Caption = 'Allocation Amount Incl. VAT (LCY)';
                    ToolTip = 'Enter how much of the received payment amount (incl. VAT) to allocate to this invoice line.';

                    trigger OnValidate()
                    var
                        LineRemaining: Decimal;
                    begin
                        LineRemaining := Rec."Orig. Amt Incl. VAT (LCY)" - Rec."Already Settled Amt (LCY)";
                        if Rec."Alloc. Amt Incl. VAT (LCY)" > LineRemaining + 0.005 then
                            Error(AllocationExceedsLineRemainingErr, LineRemaining);
                        Rec.Modify();
                        RemainingNonZero := Abs(ApplicationAmtLCY - CalcTotalAllocated()) > 0.005;
                        CurrPage.Update(false);
                    end;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DistributeProportionally)
            {
                Caption = 'Distribute Proportionally';
                ApplicationArea = All;
                Image = Suggest;
                ToolTip = 'Distributes the payment amount proportionally across all lines based on their original amounts incl. VAT. The last line absorbs any rounding difference.';

                trigger OnAction()
                begin
                    RunDistributeProportionally();
                end;
            }
            action(ApplyAllocation)
            {
                Caption = 'Apply Allocation';
                ApplicationArea = All;
                Image = Apply;
                ToolTip = 'Validates that the total allocated equals the payment amount and creates Settlement Entries. The application transaction is committed after this.';

                trigger OnAction()
                begin
                    if Abs(CalcTotalAllocated() - ApplicationAmtLCY) > 0.005 then begin
                        Message(AllocMustMatchPaymentMsg, ApplicationAmtLCY, CalcTotalAllocated());
                        exit;
                    end;
                    Applied := true;
                    CurrPage.Close();
                end;
            }
            action(CancelAllocation)
            {
                Caption = 'Cancel';
                ApplicationArea = All;
                Image = Cancel;
                ToolTip = 'Cancels the allocation. The entire payment application will be rolled back — no G/L entries or customer ledger entries will be posted.';

                trigger OnAction()
                begin
                    Applied := false;
                    CurrPage.Close();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(ApplyAllocation_Promoted; ApplyAllocation) { }
                actionref(DistributeProportionally_Promoted; DistributeProportionally) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        LoadInvoiceLines();
        RemainingNonZero := Abs(ApplicationAmtLCY - CalcTotalAllocated()) > 0.005;
    end;

    // ── Public interface (called by SettlementEntryMgt) ───────────────────────

    /// <summary>
    /// Sets the page context before the page is opened. Must be called before RunModal().
    /// </summary>
    /// <param name="NewInvoiceCLE">The customer ledger entry for the invoice being partially paid.</param>
    /// <param name="NewApplicationAmtLCY">The payment amount in LCY (incl. VAT) to distribute across invoice lines.</param>
    /// <param name="NewPostingDate">The posting date of the payment application.</param>
    /// <param name="NewBankDocNo">The bank statement document number that triggered this payment.</param>
    /// <param name="NewPaymentRef">The payment reference text from the bank statement.</param>
    procedure SetContext(NewInvoiceCLE: Record "Cust. Ledger Entry"; NewApplicationAmtLCY: Decimal; NewPostingDate: Date; NewBankDocNo: Code[20]; NewPaymentRef: Text[100])
    var
        Customer: Record Customer;
    begin
        InvoiceCLE := NewInvoiceCLE;
        InvoiceDocNo := NewInvoiceCLE."Document No.";
        CustomerNo := NewInvoiceCLE."Customer No.";
        if Customer.Get(NewInvoiceCLE."Customer No.") then
            CustomerName := Customer.Name;
        ApplicationAmtLCY := NewApplicationAmtLCY;
        PostingDate := NewPostingDate;
        BankDocNo := NewBankDocNo;
        PaymentRef := NewPaymentRef;
    end;

    /// <summary>
    /// Returns whether the user confirmed the allocation by clicking Apply Allocation.
    /// Returns false if the user cancelled or closed the page without applying.
    /// </summary>
    procedure GetApplied(): Boolean
    begin
        exit(Applied);
    end;

    /// <summary>
    /// Copies the allocation lines entered by the user into the provided temporary buffer.
    /// Only lines where the user entered an allocation amount are relevant to the caller.
    /// </summary>
    /// <param name="TempAllocBuffer">Output buffer populated with all allocation lines from the page.</param>
    procedure GetAllocationLines(var TempAllocBuffer: Record "Pmt. Alloc. Line Buffer" temporary)
    begin
        TempAllocBuffer.Reset();
        TempAllocBuffer.DeleteAll();
        if Rec.FindSet() then
            repeat
                TempAllocBuffer := Rec;
                TempAllocBuffer.Insert();
            until Rec.Next() = 0;
    end;

    // ── Private ───────────────────────────────────────────────────────────────

    var
        InvoiceCLE: Record "Cust. Ledger Entry";
        Applied: Boolean;
        RemainingNonZero: Boolean;
        BankDocNo: Code[20];
        CustomerNo: Code[20];
        InvoiceDocNo: Code[20];
        PostingDate: Date;
        ApplicationAmtLCY: Decimal;
        CustomerName: Text[100];
        PaymentRef: Text[100];
        AllocMustMatchPaymentMsg: Label 'The total allocated amount (%1) must equal the payment amount (%2) before applying. Adjust the allocation amounts.', Comment = '%1 = total allocated amount, %2 = payment amount';
        AllocationExceedsLineRemainingErr: Label 'The entered amount exceeds the remaining amount for this line (%1). A line cannot be allocated more than its outstanding balance.', Comment = '%1 = remaining amount for the line';

    /// <summary>
    /// Loads the invoice lines from the posted sales invoice into the page's temporary source table.
    /// Only lines with a non-zero amount are included.
    /// </summary>
    local procedure LoadInvoiceLines()
    var
        SalesInvLine: Record "Sales Invoice Line";
        SettlementEntryMgt: Codeunit "Settlement Entry Mgt.";
    begin
        if InvoiceDocNo = '' then
            exit;
        SalesInvLine.SetRange("Document No.", InvoiceDocNo);
        SalesInvLine.SetFilter(Amount, '<>0');
        if not SalesInvLine.FindSet() then
            exit;
        repeat
            Rec.Init();
            Rec."Line No." := SalesInvLine."Line No.";
            Rec.Description := CopyStr(SalesInvLine.Description, 1, MaxStrLen(Rec.Description));
            Rec."G/L Account No." := CopyStr(SalesInvLine."No.", 1, MaxStrLen(Rec."G/L Account No."));
            Rec."Original Amt (LCY)" := SalesInvLine.Amount;
            Rec."Orig. Amt Incl. VAT (LCY)" := SalesInvLine."Amount Including VAT";
            Rec."Already Settled Amt (LCY)" := SettlementEntryMgt.GetAlreadySettledAmtInclVAT(InvoiceDocNo, SalesInvLine."Line No.");
            Rec."Global Dimension 1 Code" := SalesInvLine."Shortcut Dimension 1 Code";
            Rec."Global Dimension 2 Code" := SalesInvLine."Shortcut Dimension 2 Code";
            Rec."Dimension Set ID" := SalesInvLine."Dimension Set ID";
            Rec.Insert();
        until SalesInvLine.Next() = 0;
    end;

    /// <summary>
    /// Returns the sum of all allocation amounts entered by the user across all invoice lines.
    /// </summary>
    local procedure CalcTotalAllocated(): Decimal
    var
        AllocLineBuffer: Record "Pmt. Alloc. Line Buffer";
    begin
        AllocLineBuffer.Copy(Rec, true); // share same temp instance
        AllocLineBuffer.CalcSums("Alloc. Amt Incl. VAT (LCY)");
        exit(AllocLineBuffer."Alloc. Amt Incl. VAT (LCY)");
    end;

    /// <summary>
    /// Distributes the payment amount proportionally across all lines based on their
    /// original amounts incl. VAT. The last line absorbs any rounding difference.
    /// </summary>
    local procedure RunDistributeProportionally()
    var
        AllocLineBuffer: Record "Pmt. Alloc. Line Buffer";
        Remaining: Decimal;
        TotalRemainingAmt: Decimal;
        CurrentLine: Integer;
        LineCount: Integer;
    begin
        AllocLineBuffer.Copy(Rec, true);

        // Compute total remaining (original minus already settled) as proportional weights.
        // Using remaining amounts ensures lines with prior partial payments receive only
        // their outstanding share — mirrors the automatic full-close distribution path.
        if AllocLineBuffer.FindSet() then
            repeat
                TotalRemainingAmt +=
                    AllocLineBuffer."Orig. Amt Incl. VAT (LCY)" - AllocLineBuffer."Already Settled Amt (LCY)";
            until AllocLineBuffer.Next() = 0;
        if TotalRemainingAmt = 0 then
            exit;

        AllocLineBuffer.Reset();
        LineCount := AllocLineBuffer.Count();
        Remaining := ApplicationAmtLCY;
        CurrentLine := 0;

        if AllocLineBuffer.FindSet(true) then
            repeat
                CurrentLine += 1;
                if CurrentLine = LineCount then
                    // Last line absorbs rounding
                    AllocLineBuffer."Alloc. Amt Incl. VAT (LCY)" := Remaining
                else begin
                    AllocLineBuffer."Alloc. Amt Incl. VAT (LCY)" :=
                        Round(ApplicationAmtLCY *
                            (AllocLineBuffer."Orig. Amt Incl. VAT (LCY)" - AllocLineBuffer."Already Settled Amt (LCY)") /
                            TotalRemainingAmt);
                    Remaining -= AllocLineBuffer."Alloc. Amt Incl. VAT (LCY)";
                end;
                AllocLineBuffer.Modify();
            until AllocLineBuffer.Next() = 0;
        RemainingNonZero := Abs(ApplicationAmtLCY - CalcTotalAllocated()) > 0.005;
        CurrPage.Update(false);
    end;
}
