namespace P3.TXL.Payment.System;

using P3.TXL.Payment.BankAccount;
using P3.TXL.Payment.Customer;
using P3.TXL.Payment.System;
using P3.TXL.Payment.Vendor;

permissionset 51100 "P3.PMT-ALL"
{
    Assignable = true;
    Permissions = codeunit "Bank Account Ledger Entries" = X,
        codeunit "Customer Ledger Entries" = X,
        codeunit "Event Subscriber" = X,
        codeunit "Update Codeunit" = X,
        codeunit "Vendor Ledger Entries" = X,
        query "Bank Account Ledger Entries" = X,
        codeunit Installation = X;
}