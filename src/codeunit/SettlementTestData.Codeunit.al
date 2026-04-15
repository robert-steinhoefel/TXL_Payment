#if TEST
namespace P3.TXL.Payment.Settlement;

using Microsoft.Finance.GeneralLedger.Journal;

/// <summary>
/// Creates reproducible test settlement entries for Power BI reporting development (Story 6.2).
/// All test entries use Assignment IDs starting with 'TST-' so DeleteTestData() can clean them up.
///
/// Scenarios:
///   1  Full settlement, no cash discount                  →  5 entries
///   2  Full settlement with 2 % cash discount             →  5 entries
///   3  Two partial payments (manual allocation)           → 10 entries
///   4  Overpayment (surplus → Unallocated entry)          →  6 entries
///   5  Underpayment (partial settlement, not closed)      →  5 entries
///   6  Cross-invoice payment (one payment, two invoices)  →  5 entries
///   7  Reversal (payment applied then unapplied)          → 10 entries
///   8  Credit memo + remaining payment                    →  7 entries
///   9  Grant Management                                   → deferred (Epic 8 dependency)
/// </summary>
codeunit 51108 "Settlement Test Data"
{
    procedure CreateAllTestScenarios()
    begin
        DeleteTestData();
        CreateScenario1_FullSettlement();
        CreateScenario2_CashDiscount();
        CreateScenario3_TwoPartialPayments();
        CreateScenario4_Overpayment();
        CreateScenario5_Underpayment();
        CreateScenario6_CrossInvoice();
        CreateScenario7_Reversal();
        CreateScenario8_CreditMemo();
    end;

    // ── Cleanup ───────────────────────────────────────────────────────────────

    procedure DeleteTestData()
    var
        SettlementEntry: Record "Settlement Entry";
    begin
        SettlementEntry.SetFilter("Assignment ID", 'TST-*');
        SettlementEntry.DeleteAll();
    end;

    // ── Scenario 1: Full settlement, no cash discount ─────────────────────────
    // Invoice TST-INV-001, 5 lines, total 10,000 EUR net / 11,900 incl. VAT.
    // Single payment covers the full amount. All lines and document fully settled.
    local procedure CreateScenario1_FullSettlement()
    var
        E: Record "Settlement Entry";
        Asgn: Code[50];
    begin
        Asgn := 'TST-C001-250115-001';
        NewLine(E, 'TST-INV-001', Asgn, 20250115D, 'BSTMT-2025-001');

        E."Document Line No." := 10000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 1: Vollausgleich'; InsertEntry(E);

        E."Document Line No." := 20000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 2000, 2380, 2000, 2380, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 1: Vollausgleich'; InsertEntry(E);

        E."Document Line No." := 30000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-A');
        SetAmounts(E, 3000, 3570, 3000, 3570, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 1: Vollausgleich'; InsertEntry(E);

        E."Document Line No." := 40000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-B');
        SetAmounts(E, 2500, 2975, 2500, 2975, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 1: Vollausgleich'; InsertEntry(E);

        E."Document Line No." := 50000; SetGL(E, '8200', 'Erlöse Consulting', 'FIN', 'PROJ-B');
        SetAmounts(E, 1500, 1785, 1500, 1785, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 1: Vollausgleich'; InsertEntry(E);
    end;

    // ── Scenario 2: Full settlement with 2 % cash discount ───────────────────
    // Invoice TST-INV-002, 5 × 1,000 EUR = 5,000 EUR net.
    // Payment 4,900 EUR + cash discount 100 EUR (2 %) distributed equally across lines.
    local procedure CreateScenario2_CashDiscount()
    var
        E: Record "Settlement Entry";
        Asgn: Code[50];
    begin
        Asgn := 'TST-C001-250201-002';
        NewLine(E, 'TST-INV-002', Asgn, 20250201D, 'BSTMT-2025-002');

        E."Document Line No." := 10000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 980, 1166.2, 20, 23.8); SetSettled(E, true, true);
        E.Description := 'Szenario 2: Skonto 2%'; InsertEntry(E);

        E."Document Line No." := 20000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 980, 1166.2, 20, 23.8); SetSettled(E, true, true);
        E.Description := 'Szenario 2: Skonto 2%'; InsertEntry(E);

        E."Document Line No." := 30000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 980, 1166.2, 20, 23.8); SetSettled(E, true, true);
        E.Description := 'Szenario 2: Skonto 2%'; InsertEntry(E);

        E."Document Line No." := 40000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-B');
        SetAmounts(E, 1000, 1190, 980, 1166.2, 20, 23.8); SetSettled(E, true, true);
        E.Description := 'Szenario 2: Skonto 2%'; InsertEntry(E);

        E."Document Line No." := 50000; SetGL(E, '8200', 'Erlöse Consulting', 'FIN', 'PROJ-B');
        SetAmounts(E, 1000, 1190, 980, 1166.2, 20, 23.8); SetSettled(E, true, true);
        E.Description := 'Szenario 2: Skonto 2%'; InsertEntry(E);
    end;

    // ── Scenario 3: Two partial payments (manual allocation) ─────────────────
    // Invoice TST-INV-003, 5 × 2,000 EUR = 10,000 EUR net.
    // Payment 1: 4,000 EUR (40 % proportional) on 2025-03-10.
    // Payment 2: 6,000 EUR (60 % remaining)    on 2025-03-31.
    // Both payments create 5 entries each → 10 entries total.
    local procedure CreateScenario3_TwoPartialPayments()
    var
        E: Record "Settlement Entry";
        Asgn: Code[50];
        Line: Integer;
    begin
        Asgn := 'TST-C001-250310-003';
        // Payment 1 — 40 %
        NewLine(E, 'TST-INV-003', Asgn, 20250310D, 'BSTMT-2025-003');
        for Line := 1 to 5 do begin
            E."Document Line No." := Line * 10000;
            SetGL(E, LineGL(Line), LineGLName(Line), LineDim1(Line), LineDim2(Line));
            SetAmounts(E, 2000, 2380, 800, 952, 0, 0); SetSettled(E, false, false);
            E.Description := 'Szenario 3: Teilzahlung 1/2'; InsertEntry(E);
        end;
        // Payment 2 — 60 %
        NewLine(E, 'TST-INV-003', Asgn, 20250331D, 'BSTMT-2025-004');
        for Line := 1 to 5 do begin
            E."Document Line No." := Line * 10000;
            SetGL(E, LineGL(Line), LineGLName(Line), LineDim1(Line), LineDim2(Line));
            SetAmounts(E, 2000, 2380, 1200, 1428, 0, 0); SetSettled(E, true, true);
            E.Description := 'Szenario 3: Teilzahlung 2/2'; InsertEntry(E);
        end;
    end;

    // ── Scenario 4: Overpayment ───────────────────────────────────────────────
    // Invoice TST-INV-004, 5 × 1,000 EUR = 5,000 EUR net.
    // Payment 5,200 EUR: each invoice line fully settled + 200 EUR Unallocated entry.
    local procedure CreateScenario4_Overpayment()
    var
        E: Record "Settlement Entry";
        Asgn: Code[50];
        Line: Integer;
    begin
        Asgn := 'TST-C001-250415-004';
        NewLine(E, 'TST-INV-004', Asgn, 20250415D, 'BSTMT-2025-005');
        for Line := 1 to 5 do begin
            E."Document Line No." := Line * 10000;
            SetGL(E, LineGL(Line), LineGLName(Line), LineDim1(Line), LineDim2(Line));
            SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, true);
            E.Description := 'Szenario 4: Überzahlung'; InsertEntry(E);
        end;
        // Unallocated surplus entry — DocumentNo intentionally blank
        E.Init();
        E."Transaction Type" := "Settlement Transaction Type"::Sales;
        E."Document Type" := "Gen. Journal Document Type"::Invoice;
        E."Settlement Entry Type" := "Settlement Entry Type"::Unallocated;
        E."Document No." := '';
        E."Assignment ID" := Asgn;
        E."Settlement Date" := 20250415D;
        E."CV No." := 'TST-C001'; E."CV Name" := 'Testkunde GmbH';
        E."Bank Statement Document No." := 'BSTMT-2025-005';
        SetAmounts(E, 200, 238, 200, 238, 0, 0); SetSettled(E, false, false);
        E.Description := 'Szenario 4: Überzahlung – nicht zugeordnet'; InsertEntry(E);
    end;

    // ── Scenario 5: Underpayment ──────────────────────────────────────────────
    // Invoice TST-INV-005, 5 × 1,000 EUR = 5,000 EUR net.
    // Payment 4,000 EUR (80 %) — invoice remains open, lines not fully settled.
    local procedure CreateScenario5_Underpayment()
    var
        E: Record "Settlement Entry";
        Asgn: Code[50];
        Line: Integer;
    begin
        Asgn := 'TST-C001-250501-005';
        NewLine(E, 'TST-INV-005', Asgn, 20250501D, 'BSTMT-2025-006');
        for Line := 1 to 5 do begin
            E."Document Line No." := Line * 10000;
            SetGL(E, LineGL(Line), LineGLName(Line), LineDim1(Line), LineDim2(Line));
            SetAmounts(E, 1000, 1190, 800, 952, 0, 0); SetSettled(E, false, false);
            E.Description := 'Szenario 5: Unterzahlung'; InsertEntry(E);
        end;
    end;

    // ── Scenario 6: Cross-invoice payment ────────────────────────────────────
    // One payment of 5,000 EUR covers two invoices simultaneously.
    // Invoice TST-INV-006A (3 lines × 1,000 EUR) + TST-INV-006B (2 lines × 1,000 EUR).
    local procedure CreateScenario6_CrossInvoice()
    var
        E: Record "Settlement Entry";
    begin
        // Invoice A — 3 lines
        NewLine(E, 'TST-INV-006A', 'TST-C001-250601-006A', 20250601D, 'BSTMT-2025-007');
        E."Document Line No." := 10000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 6: Sammelzahlung – Rechnung A'; InsertEntry(E);

        E."Document Line No." := 20000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 6: Sammelzahlung – Rechnung A'; InsertEntry(E);

        E."Document Line No." := 30000; SetGL(E, '8200', 'Erlöse Consulting', 'FIN', 'PROJ-B');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 6: Sammelzahlung – Rechnung A'; InsertEntry(E);

        // Invoice B — 2 lines
        NewLine(E, 'TST-INV-006B', 'TST-C001-250601-006B', 20250601D, 'BSTMT-2025-007');
        E."Document Line No." := 10000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 6: Sammelzahlung – Rechnung B'; InsertEntry(E);

        E."Document Line No." := 20000; SetGL(E, '8200', 'Erlöse Consulting', 'FIN', 'PROJ-B');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 6: Sammelzahlung – Rechnung B'; InsertEntry(E);
    end;

    // ── Scenario 7: Reversal (payment applied then unapplied) ────────────────
    // Invoice TST-INV-007, 5 × 2,000 EUR = 10,000 EUR net.
    // Original payment (2025-07-01) → 5 Normal entries (Reversed = true).
    // Unapplication (2025-07-15)    → 5 Reversal entries (negated amounts).
    local procedure CreateScenario7_Reversal()
    var
        E: Record "Settlement Entry";
        Asgn: Code[50];
        OrigEntryNos: array[5] of Integer;
        Line: Integer;
    begin
        Asgn := 'TST-C001-250701-007';
        // Original entries
        NewLine(E, 'TST-INV-007', Asgn, 20250701D, 'BSTMT-2025-008');
        for Line := 1 to 5 do begin
            E."Document Line No." := Line * 10000;
            SetGL(E, LineGL(Line), LineGLName(Line), LineDim1(Line), LineDim2(Line));
            SetAmounts(E, 2000, 2380, 2000, 2380, 0, 0); SetSettled(E, true, true);
            E.Description := 'Szenario 7: Original'; InsertEntry(E);
            OrigEntryNos[Line] := E."Entry No.";
        end;
        // Reversal entries
        NewLine(E, 'TST-INV-007', Asgn, 20250715D, 'BSTMT-2025-008');
        for Line := 1 to 5 do begin
            E."Document Line No." := Line * 10000;
            SetGL(E, LineGL(Line), LineGLName(Line), LineDim1(Line), LineDim2(Line));
            SetAmounts(E, 2000, 2380, -2000, -2380, 0, 0); SetSettled(E, false, false);
            E."Settlement Entry Type" := "Settlement Entry Type"::Reversal;
            E."Reversal Entry" := true;
            E."Original Entry No." := OrigEntryNos[Line];
            E.Description := 'Szenario 7: Storno'; InsertEntry(E);
            // Back-update original: Reversed = true, Reversal Entry No. = this entry
            UpdateReversed(OrigEntryNos[Line], E."Entry No.");
        end;
    end;

    // ── Scenario 8: Credit memo + remaining payment ───────────────────────────
    // Invoice TST-INV-008, 5 × 2,000 EUR = 10,000 EUR net.
    // Credit memo TST-CM-001 credits 2 × 1,000 EUR (lines 1+2).
    //   → 2 CM settlement entries (DocumentType = Credit Memo, positive amounts).
    // Remaining payment of 8,000 EUR covers all 5 invoice lines at 80 %.
    //   → 5 invoice settlement entries.
    // Note: documentFullySettled on CM entries is false (Case A timing gap — see API docs).
    local procedure CreateScenario8_CreditMemo()
    var
        E: Record "Settlement Entry";
    begin
        // Credit memo entries
        E.Init();
        E."Transaction Type" := "Settlement Transaction Type"::Sales;
        E."Document Type" := "Gen. Journal Document Type"::"Credit Memo";
        E."Settlement Entry Type" := "Settlement Entry Type"::Normal;
        E."CV No." := 'TST-C001'; E."CV Name" := 'Testkunde GmbH';
        E."Document No." := 'TST-CM-001';
        E."Assignment ID" := 'TST-C001-251101-008';
        E."Settlement Date" := 20251101D;
        E."Bank Statement Document No." := 'BSTMT-2025-009';

        E."Document Line No." := 10000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, false);
        E.Description := 'Szenario 8: Gutschrift'; InsertEntry(E);

        E."Document Line No." := 20000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-A');
        SetAmounts(E, 1000, 1190, 1000, 1190, 0, 0); SetSettled(E, true, false);
        E.Description := 'Szenario 8: Gutschrift'; InsertEntry(E);

        // Invoice payment entries (80 % of each line — remaining after CM)
        NewLine(E, 'TST-INV-008', 'TST-C001-251115-008', 20251115D, 'BSTMT-2025-010');
        E."Document Line No." := 10000; SetGL(E, '8000', 'Erlöse IT-Services', 'IT', 'PROJ-A');
        SetAmounts(E, 2000, 2380, 1600, 1904, 0, 0); SetSettled(E, false, true);
        E.Description := 'Szenario 8: Restzahlung'; InsertEntry(E);

        E."Document Line No." := 20000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-A');
        SetAmounts(E, 2000, 2380, 1600, 1904, 0, 0); SetSettled(E, false, true);
        E.Description := 'Szenario 8: Restzahlung'; InsertEntry(E);

        E."Document Line No." := 30000; SetGL(E, '8100', 'Erlöse HR-Services', 'HR', 'PROJ-B');
        SetAmounts(E, 2000, 2380, 1600, 1904, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 8: Restzahlung'; InsertEntry(E);

        E."Document Line No." := 40000; SetGL(E, '8200', 'Erlöse Consulting', 'FIN', 'PROJ-B');
        SetAmounts(E, 2000, 2380, 1600, 1904, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 8: Restzahlung'; InsertEntry(E);

        E."Document Line No." := 50000; SetGL(E, '8200', 'Erlöse Consulting', 'FIN', 'PROJ-B');
        SetAmounts(E, 2000, 2380, 1600, 1904, 0, 0); SetSettled(E, true, true);
        E.Description := 'Szenario 8: Restzahlung'; InsertEntry(E);
    end;

    // ── Helpers ───────────────────────────────────────────────────────────────

    /// Initialises a settlement entry with common Sales/Invoice/Normal defaults.
    local procedure NewLine(var E: Record "Settlement Entry"; DocNo: Code[20]; AsgnId: Code[50]; SettleDate: Date; BankDocNo: Code[20])
    begin
        E.Init();
        E."Transaction Type" := "Settlement Transaction Type"::Sales;
        E."Document Type" := "Gen. Journal Document Type"::Invoice;
        E."Settlement Entry Type" := "Settlement Entry Type"::Normal;
        E."CV No." := 'TST-C001';
        E."CV Name" := 'Testkunde GmbH';
        E."Document No." := DocNo;
        E."Assignment ID" := AsgnId;
        E."Settlement Date" := SettleDate;
        E."Bank Statement Document No." := BankDocNo;
        E."Reversal Entry" := false;
        E."Original Entry No." := 0;
        E.Reversed := false;
        E."Reversal Entry No." := 0;
    end;

    local procedure SetGL(var E: Record "Settlement Entry"; GLNo: Code[20]; GLName: Text[100]; Dim1: Code[20]; Dim2: Code[20])
    begin
        E."G/L Account No." := GLNo;
        E."G/L Account Name" := GLName;
        E."Global Dimension 1 Code" := Dim1;
        E."Global Dimension 2 Code" := Dim2;
    end;

    local procedure SetAmounts(var E: Record "Settlement Entry"; OrigAmt: Decimal; OrigAmtInclVat: Decimal; SettleAmt: Decimal; SettleAmtInclVat: Decimal; CDamt: Decimal; CDAmtInclVat: Decimal)
    begin
        E."Original Line Amt (LCY)" := OrigAmt;
        E."Orig. Line Amt Incl. VAT (LCY)" := OrigAmtInclVat;
        E."Settlement Amt (LCY)" := SettleAmt;
        E."Settlement Amt Incl. VAT (LCY)" := SettleAmtInclVat;
        E."Cash Discount Amt (LCY)" := CDamt;
        E."Cash Discount Amt Incl. VAT (LCY)" := CDAmtInclVat;
    end;

    local procedure SetSettled(var E: Record "Settlement Entry"; LineFullySettled: Boolean; DocFullySettled: Boolean)
    begin
        E."Line Fully Settled" := LineFullySettled;
        E."Document Fully Settled" := DocFullySettled;
    end;

    local procedure InsertEntry(var E: Record "Settlement Entry")
    begin
        E."Total Settled Amt (LCY)" := E."Settlement Amt (LCY)" + E."Cash Discount Amt (LCY)";
        E."Total Settled Amt Incl. VAT (LCY)" := E."Settlement Amt Incl. VAT (LCY)" + E."Cash Discount Amt Incl. VAT (LCY)";
        E.Insert();
    end;

    local procedure UpdateReversed(OrigEntryNo: Integer; ReversalEntryNo: Integer)
    var
        OrigEntry: Record "Settlement Entry";
    begin
        if not OrigEntry.Get(OrigEntryNo) then
            exit;
        OrigEntry.Reversed := true;
        OrigEntry."Reversal Entry No." := ReversalEntryNo;
        OrigEntry.Modify();
    end;

    // ── Line dimension/GL helpers (shared across scenarios 3, 5, 7) ──────────

    local procedure LineGL(Line: Integer): Code[20]
    begin
        case Line of
            1, 2:
                exit('8000');
            3, 4:
                exit('8100');
            else
                exit('8200');
        end;
    end;

    local procedure LineGLName(Line: Integer): Text[100]
    begin
        case Line of
            1, 2:
                exit('Erlöse IT-Services');
            3, 4:
                exit('Erlöse HR-Services');
            else
                exit('Erlöse Consulting');
        end;
    end;

    local procedure LineDim1(Line: Integer): Code[20]
    begin
        case Line of
            1, 2:
                exit('IT');
            3, 4:
                exit('HR');
            else
                exit('FIN');
        end;
    end;

    local procedure LineDim2(Line: Integer): Code[20]
    begin
        if Line <= 3 then
            exit('PROJ-A')
        else
            exit('PROJ-B');
    end;
}
#endif
