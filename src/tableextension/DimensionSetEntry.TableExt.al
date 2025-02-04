namespace P3.TXL.Payment.BankAccount;

using Microsoft.Finance.Dimension;

tableextension 51105 "DimensionSetEntry TableExt" extends "Dimension Set Entry"
{

    fieldgroups
    {
        addlast(DropDown; "Dimension Code", "Dimension Value Code", "Dimension Value Name") { }
    }

}
