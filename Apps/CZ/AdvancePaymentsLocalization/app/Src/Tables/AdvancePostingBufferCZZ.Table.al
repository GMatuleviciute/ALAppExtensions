﻿// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Finance.AdvancePayments;

using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Foundation.Enums;

table 31013 "Advance Posting Buffer CZZ"
{
    Caption = 'Advance Posting Buffer';
    ReplicateData = false;
    TableType = Temporary;
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "VAT Bus. Posting Group"; Code[20])
        {
            Caption = 'VAT Bus. Posting Group';
            TableRelation = "VAT Business Posting Group";
        }
        field(2; "VAT Prod. Posting Group"; Code[20])
        {
            Caption = 'VAT Prod. Posting Group';
            TableRelation = "VAT Product Posting Group";
        }
        field(7; Amount; Decimal)
        {
            Caption = 'Amount';
        }
        field(8; "VAT Amount"; Decimal)
        {
            Caption = 'VAT Amount';
        }
        field(12; "VAT Calculation Type"; Enum "Tax Calculation Type")
        {
            Caption = 'VAT Calculation Type';
        }
        field(14; "VAT Base Amount"; Decimal)
        {
            Caption = 'VAT Base Amount';
        }
        field(20; "Amount (LCY)"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Amount (LCY)';
        }
        field(21; "VAT Amount (LCY)"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'VAT Amount (LCY)';
        }
        field(22; "VAT Base Amount (LCY)"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'VAT Base Amount (LCY)';
        }
        field(25; "Amount (ACY)"; Decimal)
        {
            AutoFormatExpression = GetAdditionalReportingCurrencyCode();
            AutoFormatType = 1;
            Caption = 'Amount (ACY)';
        }
        field(26; "VAT Amount (ACY)"; Decimal)
        {
            AutoFormatExpression = GetAdditionalReportingCurrencyCode();
            AutoFormatType = 1;
            Caption = 'VAT Amount (ACY)';
        }
        field(29; "VAT Base Amount (ACY)"; Decimal)
        {
            AutoFormatExpression = GetAdditionalReportingCurrencyCode();
            AutoFormatType = 1;
            Caption = 'VAT Base Amount (ACY)';
        }
        field(32; "VAT %"; Decimal)
        {
            Caption = 'VAT %';
            DecimalPlaces = 1 : 1;
        }
        field(35; "Auxiliary Entry"; Boolean)
        {
            Caption = 'Auxiliary Entry';
        }
        field(40; "Non-Deductible VAT %"; Decimal)
        {
            Caption = 'Non-Deductible VAT %"';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(41; "Non-Deductible VAT Base"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Non-Deductible VAT Base';
        }
        field(42; "Non-Deductible VAT Amount"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Non-Deductible VAT Amount';
        }
        field(43; "Non-Deductible VAT Base ACY"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Non-Deductible VAT Base ACY';
        }
        field(44; "Non-Deductible VAT Amount ACY"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Non-Deductible VAT Amount ACY';
        }
    }

    keys
    {
        key(Key1; "VAT Bus. Posting Group", "VAT Prod. Posting Group")
        {
            Clustered = true;
        }
    }

    protected var
        GeneralLedgerSetup: Record "General Ledger Setup";

    local procedure GetAdditionalReportingCurrencyCode(): Code[10]
    begin
        exit(GeneralLedgerSetup.GetAdditionalCurrencyCodeCZL())
    end;

    procedure PrepareForPurchAdvLetterEntry(var PurchAdvLetterEntry: Record "Purch. Adv. Letter Entry CZZ")
    begin
        Clear(Rec);
        "VAT Bus. Posting Group" := PurchAdvLetterEntry."VAT Bus. Posting Group";
        "VAT Prod. Posting Group" := PurchAdvLetterEntry."VAT Prod. Posting Group";
        "VAT Calculation Type" := PurchAdvLetterEntry."VAT Calculation Type";
        "VAT %" := PurchAdvLetterEntry."VAT %";
        Amount := PurchAdvLetterEntry.Amount;
        "VAT Base Amount" := PurchAdvLetterEntry."VAT Base Amount";
        "VAT Amount" := PurchAdvLetterEntry."VAT Amount";
        "Amount (LCY)" := PurchAdvLetterEntry."Amount (LCY)";
        "VAT Base Amount (LCY)" := PurchAdvLetterEntry."VAT Base Amount (LCY)";
        "VAT Amount (LCY)" := PurchAdvLetterEntry."VAT Amount (LCY)";
        "Amount (ACY)" := "Amount (LCY)" * PurchAdvLetterEntry."Additional Currency Factor";
        "VAT Base Amount (ACY)" := "VAT Base Amount (LCY)" * PurchAdvLetterEntry."Additional Currency Factor";
        "VAT Amount (ACY)" := "VAT Amount (LCY)" * PurchAdvLetterEntry."Additional Currency Factor";
        "Auxiliary Entry" := PurchAdvLetterEntry."Auxiliary Entry";
        "Non-Deductible VAT %" := PurchAdvLetterEntry."Non-Deductible VAT %";
        OnAfterPrepareForPurchAdvLetterEntry(PurchAdvLetterEntry, Rec);
    end;

    procedure PrepareForPurchAdvLetterLine(var PurchAdvLetterLine: Record "Purch. Adv. Letter Line CZZ")
    begin
        Clear(Rec);
        "VAT Bus. Posting Group" := PurchAdvLetterLine."VAT Bus. Posting Group";
        "VAT Prod. Posting Group" := PurchAdvLetterLine."VAT Prod. Posting Group";
        "VAT Calculation Type" := PurchAdvLetterLine."VAT Calculation Type";
        "VAT %" := PurchAdvLetterLine."VAT %";
        Amount := PurchAdvLetterLine."Amount Including VAT";
        "VAT Base Amount" := PurchAdvLetterLine.Amount;
        "VAT Amount" := PurchAdvLetterLine."VAT Amount";
        "Amount (LCY)" := PurchAdvLetterLine."Amount Including VAT (LCY)";
        "VAT Base Amount (LCY)" := PurchAdvLetterLine."Amount (LCY)";
        "VAT Amount (LCY)" := PurchAdvLetterLine."VAT Amount (LCY)";
        OnAfterPrepareForPurchAdvLetterLine(PurchAdvLetterLine, Rec);
    end;

    procedure PrepareForSalesAdvLetterEntry(var SalesAdvLetterEntry: Record "Sales Adv. Letter Entry CZZ")
    begin
        Clear(Rec);
        "VAT Bus. Posting Group" := SalesAdvLetterEntry."VAT Bus. Posting Group";
        "VAT Prod. Posting Group" := SalesAdvLetterEntry."VAT Prod. Posting Group";
        "VAT Calculation Type" := SalesAdvLetterEntry."VAT Calculation Type";
        "VAT %" := SalesAdvLetterEntry."VAT %";
        Amount := SalesAdvLetterEntry.Amount;
        "VAT Base Amount" := SalesAdvLetterEntry."VAT Base Amount";
        "VAT Amount" := SalesAdvLetterEntry."VAT Amount";
        "Amount (LCY)" := SalesAdvLetterEntry."Amount (LCY)";
        "VAT Base Amount (LCY)" := SalesAdvLetterEntry."VAT Base Amount (LCY)";
        "VAT Amount (LCY)" := SalesAdvLetterEntry."VAT Amount (LCY)";
        "Amount (ACY)" := "Amount (LCY)" * SalesAdvLetterEntry."Additional Currency Factor";
        "VAT Base Amount (ACY)" := "VAT Base Amount (LCY)" * SalesAdvLetterEntry."Additional Currency Factor";
        "VAT Amount (ACY)" := "VAT Amount (LCY)" * SalesAdvLetterEntry."Additional Currency Factor";
        "Auxiliary Entry" := SalesAdvLetterEntry."Auxiliary Entry";
        OnAfterPrepareForSalesAdvLetterEntry(SalesAdvLetterEntry, Rec);
    end;

    procedure PrepareForSalesAdvLetterLine(var SalesAdvLetterLine: Record "Sales Adv. Letter Line CZZ")
    begin
        Clear(Rec);
        "VAT Bus. Posting Group" := SalesAdvLetterLine."VAT Bus. Posting Group";
        "VAT Prod. Posting Group" := SalesAdvLetterLine."VAT Prod. Posting Group";
        "VAT Calculation Type" := SalesAdvLetterLine."VAT Calculation Type";
        "VAT %" := SalesAdvLetterLine."VAT %";
        Amount := SalesAdvLetterLine."Amount Including VAT";
        "VAT Base Amount" := SalesAdvLetterLine.Amount;
        "VAT Amount" := SalesAdvLetterLine."VAT Amount";
        "Amount (LCY)" := SalesAdvLetterLine."Amount Including VAT (LCY)";
        "VAT Base Amount (LCY)" := SalesAdvLetterLine."Amount (LCY)";
        "VAT Amount (LCY)" := SalesAdvLetterLine."VAT Amount (LCY)";
        OnAfterPrepareForSalesAdvLetterLine(SalesAdvLetterLine, Rec);
    end;

    procedure Update(AdvancePostingBuffer: Record "Advance Posting Buffer CZZ")
    begin
        OnBeforeUpdate(Rec, AdvancePostingBuffer);

        Rec := AdvancePostingBuffer;
        if Find() then begin
            Amount += AdvancePostingBuffer.Amount;
            "VAT Base Amount" += AdvancePostingBuffer."VAT Base Amount";
            "VAT Amount" += AdvancePostingBuffer."VAT Amount";
            "Amount (LCY)" += AdvancePostingBuffer."Amount (LCY)";
            "VAT Base Amount (LCY)" += AdvancePostingBuffer."VAT Base Amount (LCY)";
            "VAT Amount (LCY)" += AdvancePostingBuffer."VAT Amount (LCY)";
            "Amount (ACY)" += AdvancePostingBuffer."Amount (ACY)";
            "VAT Base Amount (ACY)" += AdvancePostingBuffer."VAT Base Amount (ACY)";
            "VAT Amount (ACY)" += AdvancePostingBuffer."VAT Amount (ACY)";
            OnUpdateOnBeforeModify(Rec, AdvancePostingBuffer);
            Modify();
            OnUpdateOnAfterModify(Rec, AdvancePostingBuffer);
        end else
            Insert();

        OnAfterUpdate(Rec, AdvancePostingBuffer);
    end;

    procedure UpdateLCYAmounts(CurrencyCode: Code[10]; CurrencyFactor: Decimal)
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
    begin
        if (CurrencyCode = '') or (CurrencyFactor = 0) then begin
            Rec."VAT Base Amount (LCY)" := Rec."VAT Base Amount";
            Rec."VAT Amount (LCY)" := Rec."VAT Amount";
            Rec."Amount (LCY)" := Rec.Amount;
        end else begin
            Rec."Amount (LCY)" :=
              Round(
                CurrencyExchangeRate.ExchangeAmtFCYToLCY(
                  0D, CurrencyCode,
                  Rec.Amount, CurrencyFactor));
            Rec."VAT Amount (LCY)" :=
              Round(
                CurrencyExchangeRate.ExchangeAmtFCYToLCY(
                  0D, CurrencyCode,
                  Rec."VAT Amount", CurrencyFactor));
            Rec."VAT Base Amount (LCY)" := Rec."Amount (LCY)" - Rec."VAT Amount (LCY)";
        end;
    end;

    procedure UpdateACYAmounts(AddCurrencyFactor: Decimal)
    var
        AddCurrency: Record Currency;
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        AddCurrencyCode: Code[20];
    begin
        AddCurrencyCode := GetAdditionalReportingCurrencyCode();
        if AddCurrencyCode = '' then
            exit;

        if not AddCurrency.Get(AddCurrencyCode) then
            exit;

        Rec."Amount (ACY)" :=
            Round(CurrencyExchangeRate.ExchangeAmtLCYToFCYOnlyFactor(Rec."Amount (LCY)", AddCurrencyFactor), AddCurrency."Amount Rounding Precision");
        Rec."VAT Amount (ACY)" :=
            Round(CurrencyExchangeRate.ExchangeAmtLCYToFCYOnlyFactor(Rec."VAT Amount (LCY)", AddCurrencyFactor), AddCurrency."Amount Rounding Precision");
        Rec."VAT Base Amount (ACY)" := Rec."Amount (ACY)" - Rec."VAT Amount (ACY)";
    end;

    procedure UpdateVATAmounts()
    begin
        Amount := Round(Amount);
        case "VAT Calculation Type" of
            "VAT Calculation Type"::"Normal VAT":
                "VAT Amount" := Round(Amount * "VAT %" / (100 + "VAT %"));
            "VAT Calculation Type"::"Reverse Charge VAT":
                "VAT Amount" := 0;
        end;
        "VAT Base Amount" := Amount - "VAT Amount";
    end;

    procedure ReverseAmounts()
    begin
        Amount := -Amount;
        "VAT Base Amount" := -"VAT Base Amount";
        "VAT Amount" := -"VAT Amount";
        "Amount (LCY)" := -Rec."Amount (LCY)";
        "VAT Base Amount (LCY)" := -Rec."VAT Base Amount (LCY)";
        "VAT Amount (LCY)" := -Rec."VAT Amount (LCY)";
        "Amount (ACY)" := -"Amount (ACY)";
        "VAT Base Amount (ACY)" := -"VAT Base Amount (ACY)";
        "VAT Amount (ACY)" := -"VAT Amount (ACY)";
    end;

    internal procedure IsNonDeductibleVATAllowed(): Boolean
    var
        VATPostingSetup: Record "VAT Posting Setup";
    begin
        exit(VATPostingSetup.IsNonDeductibleVATAllowed(
            "VAT Bus. Posting Group", "VAT Prod. Posting Group"));
    end;

    internal procedure IsNonDeductibleVATAllowedInBuffer(): Boolean
    var
        AdvancePostingBufferCZZ: Record "Advance Posting Buffer CZZ";
    begin
        AdvancePostingBufferCZZ.Copy(Rec, true);
        if AdvancePostingBufferCZZ.FindSet() then
            repeat
                if AdvancePostingBufferCZZ.IsNonDeductibleVATAllowed() then
                    exit(true);
            until AdvancePostingBufferCZZ.Next() = 0;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPrepareForPurchAdvLetterEntry(var PurchAdvLetterEntry: Record "Purch. Adv. Letter Entry CZZ"; var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPrepareForPurchAdvLetterLine(var PurchAdvLetterLine: Record "Purch. Adv. Letter Line CZZ"; var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPrepareForSalesAdvLetterEntry(var SalesAdvLetterEntry: Record "Sales Adv. Letter Entry CZZ"; var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterPrepareForSalesAdvLetterLine(var SalesAdvLetterLine: Record "Sales Adv. Letter Line CZZ"; var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeUpdate(var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary; var FormAdvancePostingBuffer: Record "Advance Posting Buffer CZZ")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnUpdateOnBeforeModify(var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary; var FormAdvancePostingBuffer: Record "Advance Posting Buffer CZZ")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnUpdateOnAfterModify(var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary; var FormAdvancePostingBuffer: Record "Advance Posting Buffer CZZ")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterUpdate(var AdvancePostingBuffer: Record "Advance Posting Buffer CZZ" temporary; var FormAdvancePostingBuffer: Record "Advance Posting Buffer CZZ")
    begin
    end;
}
