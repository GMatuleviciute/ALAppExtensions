// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved. 
// Licensed under the MIT License. See License.txt in the project root for license information. 
// ------------------------------------------------------------------------------------------------

namespace Microsoft.DataMigration.C5;

using System.Integration;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Sales.Customer;
using Microsoft.Purchases.Vendor;
using Microsoft.Inventory.Item;
using Microsoft.Finance.GeneralLedger.Account;

codeunit 1860 "C5 Data Migration Mgt."
{
    Permissions = tabledata "G/L Account" = r;

    var
        DataMigratorDescTxt: Label 'Import from Microsoft Dynamics C5 2012';
        C5FileTypeTxt: Label 'Zip Files (*.zip)|*.zip';
        SomethingWentWrongErr: Label 'Oops, something went wrong.\Please try again later.';
        AccountsNotSelectedQst: Label 'You are about to migrate data for one or more entities without migrating general ledger accounts. If you continue, transactions for the entities will not be migrated. To migrate transactions, you must migrate general ledger accounts. Do you want to continue without general ledger accounts?';
        LedgerEntriesErr: Label 'To migrate C5 ledger entries you must also migrate general ledger accounts.';
        GLAccountsNotEmptyProceedMigrationQst: Label 'Chart of Accounts is already defined. There is a risk of that the duplicate G/L Accounts will cause the migration to fail. If this happens one of the solutions would be to to clear the G/L Accounts before migration or to remove the duplicates.\\Do you want to proceed with the migration?';

    procedure ImportC5Data(): Boolean
    var
        C5MigrationDashboardMgt: Codeunit "C5 Migr. Dashboard Mgt";
        ServerFile: Text;
        ZipInStream: InStream;
    begin
        if not UploadIntoStream(CopyStr(DataMigratorDescTxt, 1, 50), '', C5FileTypeTxt, ServerFile, ZipInStream) then
            exit(false);

        if not StoreStreamFileOnBlob(ZipInStream) then
            Session.LogMessage('0000M0G', SomethingWentWrongErr, Verbosity::Error, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, 'Category', C5MigrationDashboardMgt.GetC5MigrationTypeTxt());

        if not Codeunit.Run(Codeunit::"C5 Schema Reader") then
            Session.LogMessage('0000M0H', GetLastErrorText(), Verbosity::Error, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', C5MigrationDashboardMgt.GetC5MigrationTypeTxt());
        exit(true);
    end;

    procedure CreateDataMigrationEntites(var DataMigrationEntity: Record "Data Migration Entity"): Boolean
    var
        C5SchemaReader: Codeunit "C5 Schema Reader";
        NumberOfGLAccounts: Integer;
    begin
        DataMigrationEntity.InsertRecord(Database::Customer, C5SchemaReader.GetNumberOfCustomers());
        DataMigrationEntity.InsertRecord(Database::Vendor, C5SchemaReader.GetNumberOfVendors());
        DataMigrationEntity.InsertRecord(Database::Item, C5SchemaReader.GetNumberOfItems());
        NumberOfGLAccounts := C5SchemaReader.GetNumberOfAccounts();
        VerifyGLAccounts(NumberOfGLAccounts);
        DataMigrationEntity.InsertRecord(Database::"G/L Account", NumberOfGLAccounts);

        DataMigrationEntity.InsertRecord(Database::"C5 LedTrans", C5SchemaReader.GetNumberOfHistoricalEntries());
        exit(true);
    end;

    local procedure VerifyGLAccounts(NumberOfGLAccounts: Integer)
    var
        GLAccount: Record "G/L Account";
        C5MigrationDashboardMgt: Codeunit "C5 Migr. Dashboard Mgt";
    begin
        if (NumberOfGLAccounts = 0) then
            exit;

        GLAccount.ReadIsolation := IsolationLevel::ReadUncommitted;
        if GLAccount.Count() = 0 then
            exit;

        Session.LogMessage('0000PDD', 'G/L Accounts are not empty, possible clash with duplicates. The solution is to clear the G/L Accounts before migration', Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', C5MigrationDashboardMgt.GetC5MigrationTypeTxt());

        if GuiAllowed() then
            if not Confirm(GLAccountsNotEmptyProceedMigrationQst) then
                Error('')
    end;

    procedure ApplySelectedData(var DataMigrationEntity: Record "Data Migration Entity"): Boolean
    var
        DataMigrationStatus: Record "Data Migration Status";
        GeneralLedgerSetup: Record "General Ledger Setup";
        C5MigrDashboardMgt: Codeunit "C5 Migr. Dashboard Mgt";
        DataMigrationFacade: Codeunit "Data Migration Facade";
        VendorsToMigrateNb: Integer;
        CustomersToMigrateNb: Integer;
        ItemsToMigrateNb: Integer;
        ChartOfAccountToMigrateNb: Integer;
        LegacyEntriesToMigrateNb: Integer;
    begin

        if DataMigrationEntity.Get(Database::Vendor) then
            if DataMigrationEntity.Selected then
                VendorsToMigrateNb := DataMigrationEntity."No. of Records";

        if DataMigrationEntity.Get(Database::Customer) then
            if DataMigrationEntity.Selected then
                CustomersToMigrateNb := DataMigrationEntity."No. of Records";

        if DataMigrationEntity.Get(Database::Item) then
            if DataMigrationEntity.Selected then
                ItemsToMigrateNb := DataMigrationEntity."No. of Records";

        if DataMigrationEntity.Get(Database::"G/L Account") then
            if DataMigrationEntity.Selected then
                ChartOfAccountToMigrateNb := DataMigrationEntity."No. of Records";

        if DataMigrationEntity.Get(Database::"C5 LedTrans") then
            if DataMigrationEntity.Selected then
                LegacyEntriesToMigrateNb := DataMigrationEntity."No. of Records";

        if (ChartOfAccountToMigrateNb = 0) and not DataMigrationStatus.Get(C5MigrDashboardMgt.GetC5MigrationTypeTxt(), Database::"G/L Account") then begin
            if (LegacyEntriesToMigrateNb > 0) then
                Error(LedgerEntriesErr);
            if (ItemsToMigrateNb + CustomersToMigrateNb + VendorsToMigrateNb > 0) then
                if not Confirm(AccountsNotSelectedQst) then
                    exit(false);
        end;


        with GeneralLedgerSetup do begin
            if not Get() then begin
                Init();
                Insert();
            end;

            if ("LCY Code" = '') or (LegacyEntriesToMigrateNb > 0) then
                Page.RunModal(Page::"C5 Company Settings");
        end;

        C5MigrDashboardMgt.InitMigrationStatus(ItemsToMigrateNb, CustomersToMigrateNb, VendorsToMigrateNb, ChartOfAccountToMigrateNb, LegacyEntriesToMigrateNb);

        // run the actual migration in a background session
        if ItemsToMigrateNb + CustomersToMigrateNb + VendorsToMigrateNb + ChartOfAccountToMigrateNb + LegacyEntriesToMigrateNb > 0 then
            DataMigrationFacade.StartMigration(C5MigrDashboardMgt.GetC5MigrationTypeTxt(), FALSE);

        exit(true);
    end;


    local procedure StoreStreamFileOnBlob(ZipInStream: InStream): Boolean
    var
        C5SchemaParameters: Record "C5 Schema Parameters";
        BlobOutStream: OutStream;
    begin
        C5SchemaParameters.GetSingleInstance();
        C5SchemaParameters."Zip File Blob".CreateOutStream(BlobOutStream);
        if not CopyStream(BlobOutStream, ZipInStream) then begin
            OnCopyToDataBaseFailed();
            exit(false);
        end;
        C5SchemaParameters.Modify();
        Commit();
        exit(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCopyToDataBaseFailed()
    begin
    end;

}

