namespace P3.TXL.Payment.System;

using P3.TXL.Payment.BankAccount;
using P3.TXL.Payment.Customer;
using P3.TXL.Payment.Documentation;
using P3.TXL.Payment.Vendor;
using P3.TXL.Payment.Settlement;

permissionset 51100 "P3.PMT-ALL"
{
    Assignable = true;
    Permissions = codeunit "Bank Account Ledger Entries" = X,
        codeunit "Customer Ledger Entries" = X,
        codeunit "Event Subscriber" = X,
        codeunit "Update Codeunit" = X,
        codeunit "Vendor Ledger Entries" = X,
        query "Bank Account Ledger Entries" = X,
        codeunit Installation = X,
        tabledata "Settlement Entry" = RIMD,
        table "Settlement Entry" = X,
        tabledata "Pmt. Alloc. Line Buffer" = RIMD,
        table "Pmt. Alloc. Line Buffer" = X,
        codeunit "Pmt. Alloc. Context" = X,
        codeunit "Settlement Entry Mgt." = X,
        page "Payment Allocation" = X,
        page "Settlement Entry API" = X,
        page "Settlement Entry List" = X,
        codeunit "Payment Info Calculator" = X,
        codeunit "Settlement Navigate Handler" = X,
        codeunit "Doc Viewer" = X,
        page "HTML Renderer" = X
#if TEST
        , codeunit "Settlement Test Data" = X
#endif
        ;
}