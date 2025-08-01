namespace Microsoft.Finance.Latepayment;

using System.AI;
using System.Utilities;
using System.Privacy;
using System.Telemetry;

table 1950 "LP Machine Learning Setup"
{
    DataClassification = CustomerContent;
    ReplicateData = false;
    Permissions = TableData "LP Machine Learning Setup" = I;
    fields
    {
        field(1; "Primary Key"; Code[10])
        {
        }

        field(2; "Make Predictions"; Boolean)
        {
            Caption = 'Make Predictions';
            trigger OnValidate();
            var
                LPModelManagement: Codeunit "LP Model Management";
            begin
                if "Make Predictions" then begin
                    CheckSelectedModelExists();
                    if "Standard Model Quality" = 0 then begin // ensure that the model quality of the standard model is correctly evaluated for data on this company if it has never been tried before
                        LPModelManagement.EvaluateModel("Selected Model"::Standard, false);
                        GetSingleInstance(); // to refresh the standard model quality after evaluation
                        Session.LogSecurityAudit(LatePaymentPredictionTxt, SecurityOperationResult::Success, LatePaymentPredcitionEnabledTxt, AuditCategory::PolicyManagement);
                    end;
                    CheckModelQuality();
                end else
                    Session.LogSecurityAudit(LatePaymentPredictionTxt, SecurityOperationResult::Success, LatePaymentPredcitionDisabledTxt, AuditCategory::PolicyManagement);
            end;
        }

        field(3; "My Model"; Blob)
        {
        }

        field(4; "Selected Model"; Option)
        {
            OptionMembers = Standard,My;
            OptionCaption = 'Standard, My Model';
            Caption = 'Selected Model';
        }

        field(5; "My Model Quality"; Decimal)
        {
            Editable = false;
            MinValue = 0;
            MaxValue = 1;
        }

        field(6; "Standard Model Quality"; Decimal)
        {
            Editable = false;
            MinValue = 0;
            MaxValue = 1;
        }

        field(7; "Model Quality Threshold"; Decimal)
        {
            MinValue = 0;
            MaxValue = 1;
            Caption = 'Model Quality Threshold';
        }

        field(8; "Use My Model Credentials"; Boolean)
        {
            Caption = 'Use My Azure Subscription';
            trigger OnValidate()
            var
                AuditLog: Codeunit "Audit Log";
                CustomerConsentMgt: Codeunit "Customer Consent Mgt.";
                LatePaymentPredictionConsentProvidedLbl: Label 'Late Payment Prediction - consent provided by UserSecurityId %1.', Locked = true;
            begin
                if not xRec."Use My Model Credentials" and Rec."Use My Model Credentials" then
                    Rec."Use My Model Credentials" := CustomerConsentMgt.ConfirmUserConsentToMicrosoftService();
                if Rec."Use My Model Credentials" then
                    AuditLog.LogAuditMessage(StrSubstNo(LatePaymentPredictionConsentProvidedLbl, UserSecurityId()), SecurityOperationResult::Success, AuditCategory::ApplicationManagement, 4, 0);
            end;
        }

        field(9; "Custom API Uri"; Text[250])
        {
            Editable = false;
            NotBlank = true;
            ExtendedDatatype = Masked;
        }

        field(10; "Custom API Key"; Text[200])
        {
            Editable = false;
            NotBlank = true;
            ExtendedDatatype = Masked;

            trigger OnValidate()
            var
                AzureMLConnector: Codeunit "Azure ML Connector";
            begin
                AzureMLConnector.ValidateApiUrl("Custom API Key");
            end;
        }
        field(12; "OverestimatedInvNo OnLastReset"; Integer)
        {
            Editable = false;
        }

        field(13; "Last Feature Table Reset"; DateTime)
        {
            Editable = false;
        }

        field(14; "Last Background Analysis"; DateTime)
        {
            Editable = false;
        }

        field(15; "Standard Model Pdf"; Blob)
        {

        }

        field(16; "My Model Pdf"; Blob)
        {

        }

        field(17; "Posting Date OnLastML"; Date)
        {
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetSingleInstance()
    var
        LPModelManagement: Codeunit "LP Model Management";
    begin
        if not Rec.ReadPermission() then
            exit;
        if Get() then
            exit;

        Init();

        "Model Quality Threshold" := LPModelManagement.GetDefaultModelQualityThreshold();

        Insert();
    end;

    procedure GetModelAsText(ForModel: Option) Content: Text
    var
        TempBlob: Codeunit "Temp Blob";
        InStream: InStream;
    begin
        case ForModel of
            "Selected Model"::Standard:
                begin
                    NavApp.GetResource('LatePaymentStandardModel.txt', InStream);
                    InStream.Read(Content);
                    exit;
                end;
            "Selected Model"::My:
                TempBlob.FromRecord(Rec, FieldNo("My Model"));
        end;
        TempBlob.CreateInStream(InStream, TextEncoding::UTF8);
        InStream.Read(Content);
    end;

    procedure SetModel(ModelAsText: Text)
    var
        OutStream: OutStream;
    begin
        "My Model".CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.Write(ModelAsText);
    end;

    procedure GetModelQuality() ModelQuality: Decimal
    begin
        case "Selected Model" of
            "Selected Model"::Standard:
                ModelQuality := "Standard Model Quality";
            "Selected Model"::My:
                ModelQuality := "My Model Quality";
        end;
    end;

    procedure CheckModelQuality()
    var
        ModelQuality: Decimal;
    begin
        ModelQuality := GetModelQuality();
        if "Model Quality Threshold" > ModelQuality then
            error(CurrentModelLowerQualityThanDesiredErr, ModelQuality);
    end;


    procedure CheckSelectedModelExists()
    begin
        case "Selected Model" of
            "Selected Model"::My:
                if not MyModelExists() then
                    error(CurrentModelDoesNotExistErr);

            "Selected Model"::Standard:
                if not StandardModelExists() then
                    error(CurrentModelDoesNotExistErr);
        end;
    end;

    procedure MyModelExists(): Boolean
    begin
        exit(GetModelAsText("Selected Model"::My) <> '');
    end;

    procedure StandardModelExists(): Boolean
    begin
        exit(GetModelAsText("Selected Model"::Standard) <> '');
    end;

    procedure LastFeatureTableResetWasTooLongAgo(): Boolean
    begin
        if "Last Feature Table Reset" = 0DT then
            exit(true); // never ran, or invalidated intentionally

        // 15 min
        exit(CurrentDateTime() - "Last Feature Table Reset" > 15 * 60 * 1000);
    end;

    procedure LastBackgroundAnalysIsRecentEnough(): Boolean
    begin
        if "Last Background Analysis" = 0DT then
            exit(false); // never ran, or invalidated intentionally

        // 1 week
        exit(CurrentDateTime() - "Last Background Analysis" < 7 * 24 * 60 * 60 * 1000);
    end;

    [Scope('OnPrem')]
    procedure SaveApiUri(ApiUriText: Text[250])
    var
        ApiUriKeyGUID: Guid;
    begin
        ApiUriText := CopyStr(DelChr(ApiUriText, '=', ' '), 1, 250);
        if "Custom API Uri" <> '' then
            evaluate(ApiUriKeyGUID, "Custom API Uri");

        if IsNullGuid(ApiUriKeyGUID) or not IsolatedStorage.Contains(ApiUriKeyGUID, DataScope::Company) then begin
            ApiUriKeyGUID := Format(CreateGuid());
            "Custom API Uri" := ApiUriKeyGUID;
        end;

        if not EncryptionEnabled() then
            IsolatedStorage.Set(ApiUriKeyGUID, ApiUriText, DataScope::Company)
        else
            IsolatedStorage.SetEncrypted(ApiUriKeyGUID, ApiUriText, DataScope::Company);
    end;

    [NonDebuggable]
    [Scope('OnPrem')]
    procedure GetApiUri(): Text[250]
    var
        ApiUriKeyGUID: Guid;
        ApiUriValue: Text;
    begin
        if "Custom API Uri" <> '' then
            evaluate(ApiUriKeyGUID, "Custom API Uri");
        if not IsNullGuid(ApiUriKeyGUID) then
            if IsolatedStorage.Get(ApiUriKeyGUID, DataScope::Company, ApiUriValue) then
                exit(CopyStr(ApiUriValue, 1, 250));
    end;

    [Scope('OnPrem')]
    procedure SaveApiKey(ApiKeyText: SecretText)
    var
        ApiKeyKeyGUID: Guid;
    begin
        if "Custom API Key" <> '' then
            evaluate(ApiKeyKeyGUID, "Custom API Key");
        if IsNullGuid(ApiKeyKeyGUID) or not IsolatedStorage.Contains(ApiKeyKeyGUID, DataScope::Company) then begin
            ApiKeyKeyGUID := FORMAT(CreateGuid());
            "Custom API Key" := ApiKeyKeyGUID;
        end;

        if not EncryptionEnabled() then
            IsolatedStorage.Set(ApiKeyKeyGUID, ApiKeyText, DataScope::Company)
        else
            IsolatedStorage.SetEncrypted(ApiKeyKeyGUID, ApiKeyText, DataScope::Company);
    end;

    [Scope('OnPrem')]
    procedure GetApiKeyAsSecret(): SecretText
    var
        ApiKeyKeyGUID: GUID;
        ApiValue: SecretText;
    begin
        if "Custom API Key" <> '' then
            evaluate(ApiKeyKeyGUID, "Custom API Key");
        if not IsNullGuid(ApiKeyKeyGUID) then
            if IsolatedStorage.Get(FORMAT(ApiKeyKeyGUID), DataScope::Company, ApiValue) then
                exit(ApiValue);
    end;

    var
        CurrentModelLowerQualityThanDesiredErr: Label 'You cannot use the model because its quality of %1 is below the value in the Model Quality Threshold field. That means its predictions are unlikely to meet your accuracy requirements. You can evaluate the model again to confirm its quality. To use the model anyway, enter a value that is less than or equal to %1 in the Model Quality Threshold field.', Comment = '%1 = current model quality (decimal)';
        CurrentModelDoesNotExistErr: Label 'Cannot use the model because it does not exist. Try training a new model.';
        LatePaymentPredictionTxt: Label 'Late Payment Prediction', Locked = true;
        LatePaymentPredcitionEnabledTxt: Label 'Late Payment Prediction enabled', Locked = true;
        LatePaymentPredcitionDisabledTxt: Label 'Late Payment Prediction disabled', Locked = true;
}