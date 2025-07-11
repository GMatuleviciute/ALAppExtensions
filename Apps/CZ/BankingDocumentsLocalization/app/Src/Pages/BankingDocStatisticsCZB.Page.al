﻿#if not CLEAN27
// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Bank.Documents;

using Microsoft.Bank.BankAccount;

page 31269 "Banking Doc. Statistics CZB"
{
    Caption = 'Banking Document Statistics';
    Editable = false;
    PageType = Card;
    ObsoleteReason = 'The Banking Doc. Statistics CZB page will be replaced with the new four pages (Payment Order Statistics CZB, Iss. Pmt. Order Statistics CZB, Bank Statement Statistics CZB, Iss. Bank Stmt. Statistics CZB). The new pages are RunObject compatible and do not need to be run from code.';
    ObsoleteState = Pending;
    ObsoleteTag = '27.0';

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                group(Statistics)
                {
                    ShowCaption = false;
                    field(BegBalance; BegBalance)
                    {
                        Caption = 'Beginig Balance';
                        ApplicationArea = Basic, Suite;
                        ToolTip = 'Specifies the beginig balance of banking document.';
                    }
                    field(Amount; Amount)
                    {
                        Caption = 'Amount';
                        ApplicationArea = Basic, Suite;
                        ToolTip = 'Specifies the total amount for banking document lines.';
                    }
                    field(EndBalance; EndBalance)
                    {
                        Caption = 'Ending Balance';
                        ApplicationArea = Basic, Suite;
                        ToolTip = 'Specifies the ending balance of banking document.';
                    }
                }
            }
        }
    }

    var
        BegBalance: Decimal;
        Amount: Decimal;
        EndBalance: Decimal;

    procedure SetValues(DocumentBankAccountNo: Code[20]; DocumentDate: Date; DocumentAmount: Decimal)
    var
        BankAccount: Record "Bank Account";
    begin
        BankAccount.Get(DocumentBankAccountNo);
        BankAccount.SetFilter("Date Filter", '..%1', CalcDate('<-1D>', DocumentDate));
        BankAccount.CalcFields("Balance at Date");
        BegBalance := BankAccount."Balance at Date";
        Amount := DocumentAmount;
        EndBalance := BegBalance + Amount;
    end;
}
#endif