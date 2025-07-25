// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Integration.DynamicsFieldService;

using Microsoft.Integration.Dataverse;
using System.Environment;
using System.Environment.Configuration;
using System.Telemetry;
using System.Utilities;
using Microsoft.Integration.D365Sales;
using System.Globalization;

#pragma warning disable AS0130
#pragma warning disable PTE0025
page 6613 "FS Connection Setup Wizard"
#pragma warning restore AS0130
#pragma warning restore PTE0025
{
    Caption = 'Dynamics 365 Field Service Integration Setup';
    PageType = NavigatePage;
    SourceTable = "FS Connection Setup";
    SourceTableTemporary = true;

    layout
    {
        area(content)
        {
            group(BannerStandard)
            {
                Caption = '';
                Editable = false;
                Visible = TopBannerVisible and not CredentialsStepVisible;
#pragma warning disable AA0100
                field("MediaResourcesStandard.""Media Reference"""; MediaResourcesStandard."Media Reference")
#pragma warning restore AA0100
                {
                    ApplicationArea = Suite;
                    Editable = false;
                    ShowCaption = false;
                }
            }
            group(BannerDone)
            {
                Caption = '';
                Editable = false;
                Visible = TopBannerVisible and CredentialsStepVisible;
#pragma warning disable AA0100
                field("MediaResourcesDone.""Media Reference"""; MediaResourcesDone."Media Reference")
#pragma warning restore AA0100
                {
                    ApplicationArea = Suite;
                    Editable = false;
                    ShowCaption = false;
                }
            }
            group(Step1)
            {
                Visible = FirstStepVisible;
                group("Welcome to Dynamics 365 Connection Setup")
                {
                    Caption = 'Welcome to Dynamics 365 Field Service Connection Setup';
                    group(Control23)
                    {
                        InstructionalText = 'You can set up a Dynamics 365 Field Service connection to enable seamless coupling of data.';
                        ShowCaption = false;
                    }
                    group(Control21)
                    {
                        InstructionalText = 'Start by specifying the URL to your Dynamics 365 Field Service solution, such as https://mycrm.crm4.dynamics.com';
                        ShowCaption = false;
                    }
                    field(ServerAddress; Rec."Server Address")
                    {
                        ApplicationArea = Suite;
                        Editable = ConnectionStringFieldsEditable;
                        ToolTip = 'Specifies the URL of the environment that hosts the Dynamics 365 Field Service solution that you want to connect to.';

                        trigger OnValidate()
                        var
                            CRMIntegrationManagement: Codeunit "CRM Integration Management";
                        begin
                            CRMIntegrationManagement.CheckModifyCRMConnectionURL(Rec."Server Address");
                        end;
                    }
                    group(Control9)
                    {
                        InstructionalText = 'Once coupled, you can work with and synchronize data types that are common to both services, such as work order products, work order services, customer assets and bookable resources, and keep the data up-to-date in both locations.';
                        ShowCaption = false;
                    }
                }
            }
            group(Step2)
            {
                Caption = '';
                Visible = CredentialsStepVisible;
                group("Step2.1")
                {
                    Caption = '';
                    InstructionalText = 'Specify the user that will be used for synchronization between the two services.';
                    Visible = IsUserNamePasswordVisible;
                    field(Email; Rec."User Name")
                    {
                        ApplicationArea = Suite;
                        Caption = 'Email';
                        ExtendedDatatype = EMail;
                        Editable = ConnectionStringFieldsEditable;
                        ToolTip = 'Specifies the user name of a Dynamics 365 Field Service account.';
                    }
                    field(Password; Password)
                    {
                        ApplicationArea = Suite;
                        Caption = 'Password';
                        ExtendedDatatype = Masked;
                        Editable = ConnectionStringFieldsEditable;
                        ToolTip = 'Specifies the password of a Dynamics 365 Field Service user account.';

                        trigger OnValidate()
                        begin
                            PasswordSet := true;
                        end;
                    }
                }
                group(Control22)
                {
                    InstructionalText = 'This account must be a valid user in Dynamics 365 Field Service that does not have the System Administrator role.';
                    ShowCaption = false;
                    Visible = IsUserNamePasswordVisible;
                }
                group(Control20)
                {
                    InstructionalText = 'To enable the connection, fill out the settings below and choose Finish. You may be asked to specify an administrative user account in Dynamics 365 Field Service.';
                    ShowCaption = false;

                    field("Job Journal Template"; Rec."Job Journal Template")
                    {
                        ApplicationArea = Suite;
                        ShowMandatory = true;
                        ToolTip = 'Specifies the project journal template in which project journal lines will be created and coupled to work order products and work order services.';
                        Editable = EditableProjectSettings;
                    }
                    field("Job Journal Batch"; Rec."Job Journal Batch")
                    {
                        ApplicationArea = Suite;
                        ShowMandatory = true;
                        ToolTip = 'Specifies the project journal batch in which project journal lines will be created and coupled to work order products and work order services.';
                        Editable = EditableProjectSettings;
                    }
                    field("Hour Unit of Measure"; Rec."Hour Unit of Measure")
                    {
                        ApplicationArea = Suite;
                        ShowMandatory = true;
                        ToolTip = 'Specifies the unit of measure that corresponds to the ''hour'' unit that is used on Dynamics 365 Field Service bookable resources.';
                    }
                    field("Line Synch. Rule"; Rec."Line Synch. Rule")
                    {
                        ApplicationArea = Suite;
                        ToolTip = 'Specifies when to synchronize work order products and work order services.';
                        Editable = EditableProjectSettings;
                    }
                    field("Line Post Rule"; Rec."Line Post Rule")
                    {
                        ApplicationArea = Suite;
                        ToolTip = 'Specifies when to post project journal lines that are coupled to work order products and work order services.';
                        Editable = EditableProjectSettings;
                    }
                    field("Integration Type"; Rec."Integration Type")
                    {
                        ApplicationArea = Service;
                        ToolTip = 'Specifies the type of integration between Business Central and Dynamics 365 Field Service.';

                        trigger OnValidate()
                        begin
                            UpdateIntegrationTypeEditable();
                        end;
                    }
                }
                group("Advanced Settings")
                {
                    Caption = 'Advanced Settings';
                    Visible = false;
                    field(ImportFSSolution; ImportSolution)
                    {
                        ApplicationArea = Suite;
                        Caption = 'Import Dynamics 365 Field Service Integration Solution';
                        Enabled = ImportFSSolutionEnabled;
                        ToolTip = 'Specifies that the solution required for integration with Dynamics 365 Field Service will be imported.';
                    }
                    field(EnableFSConnection; EnableFSConnection)
                    {
                        ApplicationArea = Suite;
                        Caption = 'Enable Dynamics 365 Field Service Connection';
                        Enabled = EnableFSConnectionEnabled;
                        ToolTip = 'Specifies if the connection to Dynamics 365 Field Service will be enabled.';
                    }
                    field(SDKVersion; Rec."Proxy Version")
                    {
                        ApplicationArea = Suite;
                        AssistEdit = true;
                        Caption = 'Dynamics 365 SDK Version';
                        Editable = false;
                        ToolTip = 'Specifies the Microsoft Dynamics 365 (CRM) software development kit version that is used to connect to Dynamics 365 Field Service.';

                        trigger OnAssistEdit()
                        var
                            TempStack: Record TempStack temporary;
                        begin
                            if Page.RunModal(Page::"SDK Version List", TempStack) = Action::LookupOK then begin
                                Rec."Proxy Version" := TempStack.StackOrder;
                                CurrPage.Update(true);
                            end;
                        end;
                    }
                }
            }
            group(Step3)
            {
                Visible = ItemAvailabilityStepVisible;
                Caption = '';

                group(Control24)
                {
                    Caption = 'SET UP VIRTUAL TABLES';
                    InstructionalText = 'Set up Business Central Virtual Tables app in a Dataverse environment to allow Business Central to send business events to Dataverse.';
                }
                group(Control25)
                {
                    InstructionalText = 'Use the link below to go to AppSource and get the the Business Central Virtual Table app, so you can install it in your Dataverse environment. To refresh status after you install, click back and next.';
                    ShowCaption = false;

                    field("Enable Invt. Availability"; Rec."Enable Invt. Availability")
                    {
                        ApplicationArea = Suite;
                        Enabled = VirtualTableAppInstalled;
                        Visible = false;
                        ToolTip = 'Specifies if the Field Service users will be able to pull information about inventory availability by location from Business Central. This is available only if Virtual Table app is installed.';
                    }

                    field(InstallVirtualTableApp; VirtualTableAppInstallTxt)
                    {
                        ApplicationArea = All;
                        Editable = false;
                        ShowCaption = false;
                        Caption = ' ';
                        ToolTip = 'Get the Business Central Virtual Table app from Microsoft AppSource.';

                        trigger OnDrillDown()
                        begin
                            Hyperlink(GetVirtualTablesAppSourceLink());
                        end;
                    }
                }
                group(Control26)
                {
                    Visible = VirtualTableAppInstalled;
                    ShowCaption = false;

                    field(VirtualTableAppInstalledLbl; VirtualTableAppInstalledTxt)
                    {
                        ApplicationArea = Suite;
                        ToolTip = 'Indicates whether the Business Central Virtual Table app is installed in the Dataverse environment.';
                        Caption = 'The Business Central Virtual Table app is installed.';
                        Editable = false;
                        ShowCaption = false;
                        Style = Favorable;
                    }
                }
                group(Control64)
                {
                    Visible = not VirtualTableAppInstalled;
                    ShowCaption = false;

                    field(VirtualTableAppNotInstalledLbl; VirtualTableAppNotInstalledTxt)
                    {
                        ApplicationArea = Suite;
                        Tooltip = 'Indicates that the Business Central Virtual Table app is not installed in the Dataverse environment.';
                        Caption = 'The Business Central Virtual Table app is not installed.';
                        Editable = false;
                        ShowCaption = false;
                        Style = Ambiguous;
                    }
                }
                group(Control28)
                {
                    InstructionalText = 'Choose Refresh to enable above toggle when Business Central Virtual Table app is installed.';
                    ShowCaption = false;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(ActionBack)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Back';
                Enabled = BackActionEnabled;
                Image = PreviousRecord;
                InFooterBar = true;

                trigger OnAction()
                begin
                    NextStep(true);
                end;
            }
            action(ActionNext)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Next';
                Enabled = NextActionEnabled;
                Image = NextRecord;
                InFooterBar = true;

                trigger OnAction()
                begin
                    if (Step = Step::Start) and (Rec."Server Address" = '') then
                        Error(CRMURLShouldNotBeEmptyErr, CRMProductName.FSServiceName());
                    NextStep(false);
                end;
            }
            action(ActionAdvanced)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Advanced';
                Image = Setup;
                InFooterBar = true;
                Visible = false;

                trigger OnAction()
                begin
                    ShowAdvancedSettings := true;
                    AdvancedActionEnabled := false;
                    SimpleActionEnabled := true;
                end;
            }
            action(ActionSimple)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Simple';
                Image = Setup;
                InFooterBar = true;
                Visible = SimpleActionEnabled;

                trigger OnAction()
                begin
                    ShowAdvancedSettings := false;
                    AdvancedActionEnabled := true;
                    SimpleActionEnabled := false;
                end;
            }
            action(ActionRefresh)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Refresh';
                Image = Refresh;
                Visible = RefreshActionEnabled;
                InFooterBar = true;

                trigger OnAction()
                begin
                    VirtualTableAppInstalled := Rec.IsVirtualTablesAppInstalled();
                    Rec.SetupVirtualTables(VirtualTableAppInstalled);
                    CurrPage.Update(false);
                end;
            }
            action(ActionFinish)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Finish';
                Enabled = FinishActionEnabled;
                Image = Approve;
                InFooterBar = true;

                trigger OnAction()
                var
                    FeatureTelemetry: Codeunit "Feature Telemetry";
                    GuidedExperience: Codeunit "Guided Experience";
                    FSIntegrationMgt: Codeunit "FS Integration Mgt.";
                begin
                    if Rec."Authentication Type" = Rec."Authentication Type"::Office365 then
                        if Rec."User Name" = '' then
                            Error(CRMSynchUserCredentialsNeededErr, CRMProductName.FSServiceName());

                    if not FinalizeSetup() then
                        exit;
                    Page.Run(Page::"FS Connection Setup");
                    GuidedExperience.CompleteAssistedSetup(ObjectType::Page, Page::"FS Connection Setup Wizard");
                    Commit();
                    FeatureTelemetry.LogUptake('0000MBD', FSIntegrationMgt.ReturnIntegrationTypeLabel(Rec), Enum::"Feature Uptake Status"::"Set up");
                    CurrPage.Close();
                end;
            }
        }
    }

    trigger OnInit()
    begin
        LoadTopBanners();
        SetVisibilityFlags();
    end;

    trigger OnOpenPage()
    var
        FSConnectionSetup: Record "FS Connection Setup";
        CRMConnectionSetup: Record "CRM Connection Setup";
        FeatureTelemetry: Codeunit "Feature Telemetry";
        FSIntegrationMgt: Codeunit "FS Integration Mgt.";
    begin
        FSConnectionSetup.EnsureCDSConnectionIsEnabled();
        FSConnectionSetup.EnsureCRMConnectionIsEnabled();
        CRMConnectionSetup.Get();
        FSConnectionSetup.LoadConnectionStringElementsFromCDSConnectionSetup();
        FeatureTelemetry.LogUptake('0000MBE', 'Dataverse', Enum::"Feature Uptake Status"::Discovered);
        FeatureTelemetry.LogUptake('0000MBF', FSIntegrationMgt.ReturnIntegrationTypeLabel(Rec), Enum::"Feature Uptake Status"::Discovered);

        Rec.Init();
        if FSConnectionSetup.Get() then begin
            Rec."Proxy Version" := FSConnectionSetup."Proxy Version";
            Rec."Authentication Type" := FSConnectionSetup."Authentication Type";
            Rec."Server Address" := FSConnectionSetup."Server Address";
            Rec."User Name" := FSConnectionSetup."User Name";
            Rec."User Password Key" := FSConnectionSetup."User Password Key";
            Rec."Job Journal Template" := FSConnectionSetup."Job Journal Template";
            Rec."Job Journal Batch" := FSConnectionSetup."Job Journal Batch";
            Rec."Hour Unit of Measure" := FSConnectionSetup."Hour Unit of Measure";
            Rec."Line Synch. Rule" := FSConnectionSetup."Line Synch. Rule";
            Rec."Line Post Rule" := FSConnectionSetup."Line Post Rule";
            if not FSConnectionSetup.GetPassword().IsEmpty() then
                Password := '**********';
            ConnectionStringFieldsEditable := false;
        end else begin
            InitializeDefaultAuthenticationType();
            InitializeDefaultProxyVersion();
            InitializeDefaultTemplateAndBatch();
        end;
        Rec.Insert();
        Step := Step::Start;
        EnableControls();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        GuidedExperience: Codeunit "Guided Experience";
    begin
        if CloseAction = Action::OK then
            if GuidedExperience.AssistedSetupExistsAndIsNotComplete(ObjectType::Page, Page::"FS Connection Setup Wizard") then
                if not Confirm(ConnectionNotSetUpQst, false, CRMProductName.FSServiceName()) then
                    Error('');
    end;

    var
        MediaRepositoryStandard: Record "Media Repository";
        MediaRepositoryDone: Record "Media Repository";
        MediaResourcesStandard: Record "Media Resources";
        MediaResourcesDone: Record "Media Resources";
        CRMProductName: Codeunit "CRM Product Name";
        ClientTypeManagement: Codeunit "Client Type Management";
        Step: Option Start,Credentials,ItemAvailability,Finish;
        TopBannerVisible: Boolean;
        ConnectionStringFieldsEditable: Boolean;
        BackActionEnabled: Boolean;
        NextActionEnabled: Boolean;
        FinishActionEnabled: Boolean;
        RefreshActionEnabled: Boolean;
        FirstStepVisible: Boolean;
        CredentialsStepVisible: Boolean;
        ItemAvailabilityStepVisible: Boolean;
        EnableFSConnection: Boolean;
        ImportSolution: Boolean;
        EnableFSConnectionEnabled: Boolean;
        ImportFSSolutionEnabled: Boolean;
        ShowAdvancedSettings: Boolean;
        AdvancedActionEnabled: Boolean;
        SimpleActionEnabled: Boolean;
        IsUserNamePasswordVisible: Boolean;
        PasswordSet: Boolean;
        VirtualTableAppInstalled: Boolean;
        [NonDebuggable]
        Password: Text;
        EditableProjectSettings: Boolean;
        ConnectionNotSetUpQst: Label 'The %1 connection has not been set up.\\Are you sure you want to exit?', Comment = '%1 = CRM product name';
        CRMURLShouldNotBeEmptyErr: Label 'You must specify the URL of your %1 solution.', Comment = '%1 = CRM product name';
        CRMSynchUserCredentialsNeededErr: Label 'You must specify the credentials for the user account for synchronization with %1.', Comment = '%1 = CRM product name';
        Office365AuthTxt: Label 'AuthType=Office365', Locked = true;
        VirtualTableAppInstallTxt: Label 'Install Business Central Virtual Table app';
        VTAppSourceLinkTxt: Label 'https://appsource.microsoft.com/%1/product/dynamics-365/microsoftdynsmb.businesscentral_virtualentity', Locked = true;
        VirtualTableAppInstalledTxt: Label 'The Business Central Virtual Table app is installed.';
        VirtualTableAppNotInstalledTxt: Label 'The Business Central Virtual Table app is not installed.';

    local procedure LoadTopBanners()
    begin
        if MediaRepositoryStandard.Get('AssistedSetup-NoText-120px.png', Format(ClientTypeManagement.GetCurrentClientType())) and
           MediaRepositoryDone.Get('AssistedSetupDone-NoText-120px.png', Format(ClientTypeManagement.GetCurrentClientType()))
        then
            if MediaResourcesStandard.Get(MediaRepositoryStandard."Media Resources Ref") and
               MediaResourcesDone.Get(MediaRepositoryDone."Media Resources Ref")
            then
                TopBannerVisible := MediaResourcesDone."Media Reference".HasValue;
    end;

    local procedure SetVisibilityFlags()
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
    begin
        IsUserNamePasswordVisible := true;

        if CDSConnectionSetup.Get() then
            if CDSConnectionSetup."Authentication Type" = CDSConnectionSetup."Authentication Type"::Office365 then
                if not CDSConnectionSetup."Connection String".Contains(Office365AuthTxt) then
                    IsUserNamePasswordVisible := false;
    end;

    local procedure NextStep(Backward: Boolean)
    begin
        if Backward then
            Step := Step - 1
        else
            Step := Step + 1;

        EnableControls();
    end;

    local procedure ResetControls()
    begin
        BackActionEnabled := false;
        NextActionEnabled := false;
        FinishActionEnabled := false;
        AdvancedActionEnabled := false;

        FirstStepVisible := false;
        CredentialsStepVisible := false;
        ItemAvailabilityStepVisible := false;

        ImportFSSolutionEnabled := true;
    end;

    local procedure EnableControls()
    begin
        ResetControls();

        case Step of
            Step::Start:
                ShowStartStep();
            Step::Credentials:
                ShowCredentialsStep();
            Step::ItemAvailability:
                ShowItemAvailabilityStep();
        end;
    end;

    local procedure ShowStartStep()
    begin
        BackActionEnabled := false;
        NextActionEnabled := true;
        FinishActionEnabled := false;
        FirstStepVisible := true;
        AdvancedActionEnabled := false;
        SimpleActionEnabled := false;
        RefreshActionEnabled := false;
    end;

    local procedure ShowCredentialsStep()
    var
        FSConnectionSetup: Record "FS Connection Setup";
    begin
        BackActionEnabled := true;
        NextActionEnabled := true;
        AdvancedActionEnabled := not ShowAdvancedSettings;
        SimpleActionEnabled := not AdvancedActionEnabled;
        CredentialsStepVisible := true;
        FinishActionEnabled := false;
        RefreshActionEnabled := false;

        EnableFSConnectionEnabled := Rec."Server Address" <> '';
        Rec."Authentication Type" := Rec."Authentication Type"::Office365;

        if FSConnectionSetup.Get() then begin
            EnableFSConnection := true;
            EnableFSConnectionEnabled := not FSConnectionSetup."Is Enabled";
            ImportSolution := true;
            if FSConnectionSetup."Is FS Solution Installed" then
                ImportFSSolutionEnabled := false;
            Rec."Integration Type" := FSConnectionSetup."Integration Type";
        end else begin
            if ImportFSSolutionEnabled then
                ImportSolution := true;
            if EnableFSConnectionEnabled then
                EnableFSConnection := true;
        end;

        UpdateIntegrationTypeEditable();
    end;

    local procedure ShowItemAvailabilityStep()
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
    begin
        BackActionEnabled := true;
        NextActionEnabled := false;
        FinishActionEnabled := true;
        FirstStepVisible := false;
        AdvancedActionEnabled := false;
        SimpleActionEnabled := false;
        RefreshActionEnabled := true;
        ItemAvailabilityStepVisible := true;
        CDSConnectionSetup.Get();
        if CDSConnectionSetup."Business Events Enabled" then
            VirtualTableAppInstalled := true
        else begin
            VirtualTableAppInstalled := Rec.IsVirtualTablesAppInstalled();
            Rec.SetupVirtualTables(VirtualTableAppInstalled);
        end;
    end;

    local procedure FinalizeSetup(): Boolean
    var
        FSConnectionSetup: Record "FS Connection Setup";
        FSIntegrationMgt: Codeunit "FS Integration Mgt.";
        CDSIntegrationImpl: Codeunit "CDS Integration Impl.";
        AdminEmail: Text;
        AdminPassword: SecretText;
        AccessToken: SecretText;
        AdminADDomain: Text;
        ImportSolutionFailed: Boolean;
    begin
        if ImportSolution and ImportFSSolutionEnabled then begin
            case Rec."Authentication Type" of
                Rec."Authentication Type"::Office365:
                    CDSIntegrationImpl.GetAccessToken(Rec."Server Address", true, AccessToken);
                Rec."Authentication Type"::AD:
                    if not Rec.PromptForCredentials(AdminEmail, AdminPassword, AdminADDomain) then
                        exit(false);
                else
                    if not Rec.PromptForCredentials(AdminEmail, AdminPassword) then
                        exit(false);
            end;
            FSIntegrationMgt.ImportFSSolution(Rec."Server Address", Rec."User Name", AdminEmail, AdminPassword, AccessToken, AdminADDomain, Rec."Proxy Version", true, ImportSolutionFailed);
        end;
        if PasswordSet then
            FSConnectionSetup.UpdateFromWizard(Rec, Password)
        else
            FSConnectionSetup.UpdateFromWizard(Rec, FSConnectionSetup.GetPassword());

        if EnableFSConnection then
            FSConnectionSetup.EnableFSConnectionFromWizard();
        exit(true);
    end;

    local procedure InitializeDefaultAuthenticationType()
    begin
        Rec.Validate("Authentication Type", Rec."Authentication Type"::Office365);
    end;

    local procedure InitializeDefaultProxyVersion()
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        Rec.Validate("Proxy Version", CRMIntegrationManagement.GetLastProxyVersionItem());
    end;

    local procedure InitializeDefaultTemplateAndBatch()
    begin
        Rec.InitializeDefaultTemplateAndBatch();
    end;

    local procedure GetVirtualTablesAppSourceLink(): Text
    var
        UserSettingsRecord: Record "User Settings";
        Language: Codeunit Language;
        UserSettings: Codeunit "User Settings";
        LanguageID: Integer;
        CultureName: Text;
    begin
        UserSettings.GetUserSettings(Database.UserSecurityId(), UserSettingsRecord);
        LanguageID := UserSettingsRecord."Language ID";
        if (LanguageID = 0) then
            LanguageID := 1033; // Default to EN-US
        CultureName := Language.GetCultureName(LanguageID).ToLower();
        exit(Text.StrSubstNo(VTAppSourceLinkTxt, CultureName));
    end;

    local procedure UpdateIntegrationTypeEditable()
    begin
        EditableProjectSettings := Rec."Integration Type" = Rec."Integration Type"::Projects;
    end;
}

