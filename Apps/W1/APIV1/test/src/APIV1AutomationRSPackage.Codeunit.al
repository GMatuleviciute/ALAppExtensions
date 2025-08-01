codeunit 139731 "APIV1 - Automation RS Package"
{
    // version Test,ERM,W1,All

    Subtype = Test;
    TestType = Uncategorized;
    TestPermissions = Disabled;

    trigger OnRun()
    begin
        // [FEATURE] [Graph] [Config. Package]
    end;

    var
        LibraryRapidStart: Codeunit "Library - Rapid Start";
        LibraryGraphMgt: Codeunit "Library - Graph Mgt";
        LibraryUtility: Codeunit "Library - Utility";
        Assert: Codeunit "Assert";
        IsInitialized: Boolean;
        SamplePackageFile: Text;
        PackageCodeTxt: Label 'code', Locked = true;
        ActionImportTxt: Label 'Microsoft.NAV.import';
        ActionApplyTxt: Label 'Microsoft.NAV.apply';
        RSPackageServiceTxt: Label 'configurationPackages', Locked = true;
        SamplePackageCode: Code[20];

    [Normal]
    procedure Initialize()
    var
        TenantConfigPackageFile: Record "Tenant Config. Package File";
    begin
        TenantConfigPackageFile.DELETEALL(TRUE);

        IF IsInitialized THEN
            EXIT;

        SamplePackageFile := GenerateSamplePackageFile();
        IsInitialized := TRUE;
    end;

    [Test]
    procedure TestCreateRSPackage()
    var
        PackageCode: Code[20];
        PackageJSON: Text;
        ResponseText: Text;
        TargetURL: Text;
    begin
        // [SCENARIO] Create an RSPackage through a POST method and check if it was created
        Initialize();

        // [GIVEN] a JSON text with only Packge Code property
        PackageCode := COPYSTR(LibraryUtility.GenerateRandomAlphabeticText(20, 0), 1, 20);
        PackageJSON := CreateRSPackageJSON(PackageCode);

        COMMIT();
        // [WHEN] we POST the JSON to the web service
        TargetURL := LibraryGraphMgt.CreateTargetURL('', PAGE::"APIV1 - Aut. Config. Packages", '');
        LibraryGraphMgt.PostToWebService(TargetURL, PackageJSON, ResponseText);

        // [THEN] the response text should contain the package information
        Assert.AreNotEqual('', ResponseText, 'JSON Should not be blank');
        VerifyPackageCodeInJson(ResponseText, PackageCode);

        // clean up after the test
        LibraryRapidStart.CleanUp(PackageCode);
    end;

    [Test]
    procedure TestUploadRSPackageFile()
    var
        ConfigPackage: Record "Config. Package";
        TenantConfigPackageFile: Record "Tenant Config. Package File";
        TempBlobRSPackageFile: Codeunit "Temp Blob";
        ResponseText: Text;
        TargetURL: Text;
    begin
        // [SCENARIO] User can update RSPackage through the RSPackage API.
        Initialize();

        // [GIVEN] A Configuration package and Tenant Config Package File
        ReadRSPackageFileIntoBlob(TempBlobRSPackageFile, SamplePackageFile);

        LibraryRapidStart.CreatePackage(ConfigPackage);
        TenantConfigPackageFile.VALIDATE(Code, ConfigPackage.Code);
        TenantConfigPackageFile.INSERT(TRUE);

        COMMIT();
        // [WHEN] A PATCH request is made to the Attachment API.
        TargetURL := LibraryGraphMgt.CreateTargetURLWithSubpage(
            FormatRSCode(ConfigPackage.Code), PAGE::"APIV1 - Aut. Config. Packages", RSPackageServiceTxt,
            STRSUBSTNO('file(''%1'')/content', ConfigPackage.Code));
        LibraryGraphMgt.BinaryUpdateToWebServiceAndCheckResponseCode(TargetURL, TempBlobRSPackageFile, 'PATCH', ResponseText, 204);

        // [THEN] The package file should not exist in the response
        Assert.AreEqual('', ResponseText, 'Response should be empty');

        // [THEN] The content is correctly updated.
        TenantConfigPackageFile.GET(ConfigPackage.Code);
        Assert.IsTrue(TenantConfigPackageFile.Content.HASVALUE(), 'Configuration Package File content should have a value.');

        // clean up after the test
        LibraryRapidStart.CleanUp(ConfigPackage.Code);
    end;

    [Test]
    procedure TestImportRSPackage()
    var
        ConfigPackage: Record "Config. Package";
        TenantConfigPackageFile: Record "Tenant Config. Package File";
        TempBlobRSPackageFile: Codeunit "Temp Blob";
        RecordRef: RecordRef;
        StartTime: DateTime;
        ResponseText: Text;
        TargetURL: Text;
    begin
        // [SCENARIO] Create a rapidStart Package, upload file, and impor the package
        Initialize();

        // [GIVEN] a created package with file uploaded
        ReadRSPackageFileIntoBlob(TempBlobRSPackageFile, SamplePackageFile);

        CreateTestPackage(ConfigPackage);
        ConfigPackage.Validate("Package Name", ConfigPackage.Code);
        ConfigPackage.Modify(true);
        TenantConfigPackageFile.Validate(Code, ConfigPackage.Code);
        RecordRef.GetTable(TenantConfigPackageFile);
        TempBlobRSPackageFile.ToRecordRef(RecordRef, TenantConfigPackageFile.FieldNo(Content));
        RecordRef.SetTable(TenantConfigPackageFile);
        TenantConfigPackageFile.Insert(TRUE);

        Commit();
        // [WHEN] invoke the import action
        TargetURL :=
          LibraryGraphMgt.CreateTargetURLWithSubpage(
            FormatRSCode(ConfigPackage.Code), PAGE::"APIV1 - Aut. Config. Packages", RSPackageServiceTxt, ActionImportTxt);
        LibraryGraphMgt.PostToWebServiceAndCheckResponseCode(TargetURL, '', ResponseText, 200);

        // [THEN] the response text should be empty
        Assert.AreEqual('', ResponseText, 'Response should be empty');

        StartTime := CURRENTDATETIME();

        REPEAT
            ConfigPackage.FIND();
        UNTIL (NOT IsImportPending(ConfigPackage)) OR
              (CURRENTDATETIME() - StartTime > 180000);

        Assert.AreEqual(ConfigPackage."Import Status", ConfigPackage."Import Status"::Completed, 'Import Status should be completed.');

        // clean up after the test
        LibraryRapidStart.CleanUp(ConfigPackage.Code);
    end;

    [Test]
    procedure TestImportWrongRSPackage()
    var
        ConfigPackage: Record "Config. Package";
        TenantConfigPackageFile: Record "Tenant Config. Package File";
        TempBlobRSPackageFile: Codeunit "Temp Blob";
        RecordRef: RecordRef;
        StartTime: DateTime;
        ResponseText: Text;
        TargetURL: Text;
    begin
        // [SCENARIO] Create a rapidStart Package, upload file, and impor the package
        Initialize();

        // [GIVEN] a created package with file uploaded
        GenerateRSPackageWithRandomContent(TempBlobRSPackageFile);

        LibraryRapidStart.CreatePackage(ConfigPackage);
        TenantConfigPackageFile.Validate(Code, ConfigPackage.Code);

        RecordRef.GetTable(TenantConfigPackageFile);
        TempBlobRSPackageFile.ToRecordRef(RecordRef, TenantConfigPackageFile.FieldNo(Content));
        RecordRef.SetTable(TenantConfigPackageFile);
        TenantConfigPackageFile.Insert(true);

        Commit();
        // [WHEN] invoke the import action
        TargetURL :=
          LibraryGraphMgt.CreateTargetURLWithSubpage(
            FormatRSCode(ConfigPackage.Code), PAGE::"APIV1 - Aut. Config. Packages", RSPackageServiceTxt, ActionImportTxt);
        LibraryGraphMgt.PostToWebServiceAndCheckResponseCode(TargetURL, '', ResponseText, 200);

        // [THEN] the response text should be empty
        Assert.AreEqual('', ResponseText, 'Response should be empty');

        StartTime := CURRENTDATETIME();

        REPEAT
            ConfigPackage.FIND();
        UNTIL (NOT IsImportPending(ConfigPackage)) OR
              (CURRENTDATETIME() - StartTime > 180000);

        Assert.AreEqual(ConfigPackage."Import Status", ConfigPackage."Import Status"::Error, 'Import Status should be error.');

        // clean up after the test
        LibraryRapidStart.CleanUp(ConfigPackage.Code);
    end;

    [Test]
    procedure TestApplyRSPackage()
    var
        ConfigPackage: Record "Config. Package";
        TenantConfigPackageFile: Record "Tenant Config. Package File";
        TempBlobRSPackageFile: Codeunit "Temp Blob";
        RecordRef: RecordRef;
        StartTime: DateTime;
        ResponseText: Text;
        TargetURL: Text;
    begin
        // [SCENARIO] Create a rapidStart Package, upload file, and impor the package
        Initialize();

        // [GIVEN] a created package with file uploaded and imported
        ReadRSPackageFileIntoBlob(TempBlobRSPackageFile, SamplePackageFile);

        CreateTestPackage(ConfigPackage);
        TenantConfigPackageFile.VALIDATE(Code, ConfigPackage.Code);

        RecordRef.GetTable(TenantConfigPackageFile);
        TempBlobRSPackageFile.ToRecordRef(RecordRef, TenantConfigPackageFile.FieldNo(Content));
        RecordRef.SetTable(TenantConfigPackageFile);
        TenantConfigPackageFile.INSERT(TRUE);

        CODEUNIT.RUN(CODEUNIT::"Automation - Import RSPackage", ConfigPackage);

        COMMIT();
        // [WHEN] invoke the apply action
        TargetURL :=
          LibraryGraphMgt.CreateTargetURLWithSubpage(
            FormatRSCode(ConfigPackage.Code), PAGE::"APIV1 - Aut. Config. Packages", RSPackageServiceTxt, ActionApplyTxt);
        LibraryGraphMgt.PostToWebServiceAndCheckResponseCode(TargetURL, '', ResponseText, 200);

        // [THEN] the response text should be empty
        Assert.AreEqual('', ResponseText, 'Response should be empty');

        StartTime := CURRENTDATETIME();

        REPEAT
            ConfigPackage.FIND();
        UNTIL (NOT IsApplyPending(ConfigPackage)) OR
              (CURRENTDATETIME() - StartTime > 180000);

        Assert.AreEqual(ConfigPackage."Apply Status", ConfigPackage."Apply Status"::Completed, 'Apply Status should be completed.');
        Assert.AreEqual(0, ConfigPackage."No. of Errors", 'There should be no errors.');

        // clean up after the test
        LibraryRapidStart.CleanUp(ConfigPackage.Code);
    end;

    local procedure CreateRSPackageJSON(PackageCode: Text): Text
    var
        RSPackageJSON: Text;
    begin
        RSPackageJSON := LibraryGraphMgt.AddPropertytoJSON('', PackageCodeTxt, PackageCode);
        EXIT(RSPackageJSON);
    end;

    local procedure VerifyPackageCodeInJson(JSONTxt: Text; ExpectedID: Text)
    var
        ConfigPackage: Record "Config. Package";
        CodeValue: Text;
    begin
        Assert.IsTrue(LibraryGraphMgt.GetObjectIDFromJSON(JSONTxt, PackageCodeTxt, CodeValue), 'Could not find ItemId');
        Assert.AreEqual(ExpectedID, CodeValue, 'Package Code does not match');
        ConfigPackage.SetRange(Code, CodeValue);
        Assert.IsFalse(ConfigPackage.IsEmpty(), 'Package does not exist');
    end;

    local procedure GenerateSamplePackageFile() FilePath: Text
    var
        ConfigPackage: Record "Config. Package";
        ConfigPackageTable: Record "Config. Package Table";
    begin
        LibraryRapidStart.CreatePackage(ConfigPackage);
        LibraryRapidStart.CreatePackageTable(ConfigPackageTable, ConfigPackage.Code, DATABASE::Customer);
        ConfigPackage.VALIDATE("Exclude Config. Tables", TRUE);
        ConfigPackage.MODIFY(TRUE);
        ExportToXML(ConfigPackage.Code, ConfigPackageTable, FilePath);
        SamplePackageCode := ConfigPackage.Code;
        LibraryRapidStart.CleanUp(ConfigPackage.Code);
    end;

    local procedure ExportToXML(PackageCode: Code[20]; var ConfigPackageTable: Record "Config. Package Table"; var FilePath: Text)
    var
        ConfigXMLExchange: Codeunit "Config. XML Exchange";
        ConfigPckgCompressionMgt: Codeunit "Config. Pckg. Compression Mgt.";
        FileManagement: Codeunit "File Management";
        DecompressedFile: Text;
    begin
        DecompressedFile := FileManagement.ServerTempFileName('xml');
        ConfigPackageTable.SETRANGE("Package Code", PackageCode);
        ConfigXMLExchange.SetHideDialog(TRUE);
        ConfigXMLExchange.SetCalledFromCode(TRUE);
        ConfigXMLExchange.ExportPackageXML(ConfigPackageTable, DecompressedFile);
        // compress the file
        FilePath := FileManagement.ServerTempFileName('');
        ConfigPckgCompressionMgt.ServersideCompress(DecompressedFile, FilePath);
    end;

    local procedure GenerateRSPackageWithRandomContent(var TempBlob: Codeunit "Temp Blob")
    var
        OutStream: OutStream;
    begin
        TempBlob.CreateOutStream(OutStream);
        OutStream.WRITETEXT(CREATEGUID());
    end;

    local procedure ReadRSPackageFileIntoBlob(var TempBlobRSPackageFile: Codeunit "Temp Blob"; RSPackageFile: Text)
    var
        FileManagement: Codeunit "File Management";
    begin
        FileManagement.BLOBImportFromServerFile(TempBlobRSPackageFile, RSPackageFile);
    end;

    local procedure FormatRSCode(PackageCode: Code[20]): Text
    begin
        EXIT(STRSUBSTNO('''%1''', PackageCode));
    end;

    local procedure IsImportPending(var ConfigPackage: Record "Config. Package"): Boolean
    begin
        EXIT(ConfigPackage."Import Status" IN [ConfigPackage."Import Status"::Scheduled, ConfigPackage."Import Status"::InProgress]);
    end;

    local procedure IsApplyPending(var ConfigPackage: Record "Config. Package"): Boolean
    begin
        EXIT(ConfigPackage."Apply Status" IN [ConfigPackage."Import Status"::Scheduled, ConfigPackage."Apply Status"::InProgress]);
    end;

    local procedure CreateTestPackage(var ConfigPackage: Record "Config. Package")
    begin
        ConfigPackage.VALIDATE(Code, SamplePackageCode);
        ConfigPackage.INSERT(TRUE);
    end;
}


























