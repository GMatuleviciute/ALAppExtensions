// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Purchases.History;

using Microsoft.Bank.Setup;
using Microsoft.Finance.Currency;
using Microsoft.Finance.VAT.Calculation;
using Microsoft.Purchases.Vendor;

tableextension 11730 "Purch. Inv. Header CZL" extends "Purch. Inv. Header"
{
    fields
    {
        field(11717; "Specific Symbol CZL"; Code[10])
        {
            Caption = 'Specific Symbol';
            OptimizeForTextSearch = true;
            CharAllowed = '09';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(11718; "Variable Symbol CZL"; Code[10])
        {
            Caption = 'Variable Symbol';
            OptimizeForTextSearch = true;
            CharAllowed = '09';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(11719; "Constant Symbol CZL"; Code[10])
        {
            Caption = 'Constant Symbol';
            OptimizeForTextSearch = true;
            CharAllowed = '09';
            TableRelation = "Constant Symbol CZL";
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(11720; "Bank Account Code CZL"; Code[20])
        {
            Caption = 'Bank Account Code';
            TableRelation = "Vendor Bank Account".Code where("Vendor No." = field("Pay-to Vendor No."));
            Editable = false;
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                VendorBankAccount: Record "Vendor Bank Account";
            begin
                if "Bank Account Code CZL" = '' then begin
                    UpdateBankInfoCZL('', '', '', '', '', '', '');
                    exit;
                end;
                TestField("Pay-to Vendor No.");
                VendorBankAccount.Get("Pay-to Vendor No.", "Bank Account Code CZL");
                UpdateBankInfoCZL(
                  VendorBankAccount.Code,
                  VendorBankAccount."Bank Account No.",
                  VendorBankAccount."Bank Branch No.",
                  VendorBankAccount.Name,
                  VendorBankAccount."Transit No.",
                  VendorBankAccount.IBAN,
                  VendorBankAccount."SWIFT Code");
            end;
        }
        field(11721; "Bank Account No. CZL"; Text[30])
        {
            Caption = 'Bank Account No.';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(11722; "Bank Branch No. CZL"; Text[20])
        {
            Caption = 'Bank Branch No.';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(11723; "Bank Name CZL"; Text[100])
        {
            Caption = 'Bank Name';
            DataClassification = CustomerContent;
        }
        field(11724; "Transit No. CZL"; Text[20])
        {
            Caption = 'Transit No.';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(11725; "IBAN CZL"; Code[50])
        {
            Caption = 'IBAN';
            Editable = false;
            DataClassification = CustomerContent;
        }
        field(11726; "SWIFT Code CZL"; Code[20])
        {
            Caption = 'SWIFT Code';
            Editable = false;
            TableRelation = "SWIFT Code";
            DataClassification = CustomerContent;
        }
        field(11750; "Additional Currency Factor CZL"; Decimal)
        {
            Caption = 'Additional Currency Factor';
            DecimalPlaces = 0 : 15;
            MinValue = 0;
            DataClassification = CustomerContent;
        }
        field(11774; "VAT Currency Factor CZL"; Decimal)
        {
            Caption = 'VAT Currency Factor';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 15;
            Editable = false;
            MinValue = 0;
        }
        field(11775; "VAT Currency Code CZL"; Code[10])
        {
            Caption = 'VAT Currency Code';
            DataClassification = CustomerContent;
            TableRelation = Currency;
            Editable = false;
        }
#if not CLEANSCHEMA25
        field(11780; "VAT Date CZL"; Date)
        {
            Caption = 'VAT Date';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteTag = '25.0';
            ObsoleteReason = 'Replaced by VAT Reporting Date.';
        }
#endif
        field(11781; "Registration No. CZL"; Text[20])
        {
            Caption = 'Registration No.';
            DataClassification = CustomerContent;
        }
        field(11782; "Tax Registration No. CZL"; Text[20])
        {
            Caption = 'Tax Registration No.';
            DataClassification = CustomerContent;
        }
#if not CLEANSCHEMA25
        field(31068; "Physical Transfer CZL"; Boolean)
        {
            Caption = 'Physical Transfer';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteTag = '25.0';
            ObsoleteReason = 'Intrastat related functionalities are moved to Intrastat extensions.';
        }
        field(31069; "Intrastat Exclude CZL"; Boolean)
        {
            Caption = 'Intrastat Exclude';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteTag = '25.0';
            ObsoleteReason = 'Intrastat related functionalities are moved to Intrastat extensions. This field is not used any more.';
        }
#endif
        field(31072; "EU 3-Party Intermed. Role CZL"; Boolean)
        {
            Caption = 'EU 3-Party Intermediate Role';
            DataClassification = CustomerContent;
        }
#if not CLEANSCHEMA27
        field(31073; "EU 3-Party Trade CZL"; Boolean)
        {
            Caption = 'EU 3-Party Trade';
            DataClassification = CustomerContent;
            ObsoleteState = Removed;
            ObsoleteTag = '27.0';
            ObsoleteReason = 'Replaced by "EU 3 Party Trade" field in "EU 3-Party Trade Purchase" app.';
        }
#endif
        field(31112; "Original Doc. VAT Date CZL"; Date)
        {
            Caption = 'Original Document VAT Date';
            Editable = false;
            DataClassification = CustomerContent;
        }
    }

    var
        PopUpVATLCYCorrection: Boolean;

    procedure SetPopUpVATLCYCorrectionCZL(NewPopUpVATLCYCorrection: Boolean)
    begin
        PopUpVATLCYCorrection := NewPopUpVATLCYCorrection;
    end;

    procedure GetPopUpVATLCYCorrectionCZL(): Boolean
    begin
        exit(PopUpVATLCYCorrection);
    end;

    procedure MakeVATLCYCorrectionCZL()
    var
        VATLCYCorrectionCZL: Page "VAT LCY Correction CZL";
    begin
        VATLCYCorrectionCZL.InitGlobals(Rec);
        VATLCYCorrectionCZL.Run();
    end;

    procedure IsVATLCYCorrectionAllowedCZL(): Boolean
    begin
        Rec.CalcFields("Amount Including VAT", "Amount");
        exit((Rec."Currency Code" <> '') and ((Rec."Amount Including VAT" - Rec."Amount") <> 0));
    end;

    procedure UpdateBankInfoCZL(BankAccountCode: Code[20]; BankAccountNo: Text[30]; BankBranchNo: Text[20]; BankName: Text[100]; TransitNo: Text[20]; IBANCode: Code[50]; SWIFTCode: Code[20])
    begin
        "Bank Account Code CZL" := BankAccountCode;
        "Bank Account No. CZL" := BankAccountNo;
        "Bank Branch No. CZL" := BankBranchNo;
        "Bank Name CZL" := BankName;
        "Transit No. CZL" := TransitNo;
        "IBAN CZL" := IBANCode;
        "SWIFT Code CZL" := SWIFTCode;
        OnAfterUpdateBankInfoCZL(Rec);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterUpdateBankInfoCZL(var PurchInvHeader: Record "Purch. Inv. Header")
    begin
    end;
}