codeunit 139628 "E-Doc. Receive Test"
{
    Subtype = Test;
    TestType = Uncategorized;
    TestPermissions = Disabled;
    EventSubscriberInstance = Manual;

    trigger OnRun()
    begin
        // [FEATURE] [E-Document]
    end;

    var
        PurchaseHeader, CreatedPurchaseHeader : Record "Purchase Header";
        PurchaseLine, CreatedPurchaseLine : Record "Purchase Line";
        Vendor: Record Vendor;
        CountryRegion: Record "Country/Region";
        LibraryERM: Codeunit "Library - ERM";
        LibraryRandom: Codeunit "Library - Random";
        LibraryEDoc: Codeunit "Library - E-Document";
        LibraryPurchase: Codeunit "Library - Purchase";
        LibraryInventory: Codeunit "Library - Inventory";
        LibraryJournals: Codeunit "Library - Journals";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        PurchOrderTestBuffer: Codeunit "E-Doc. Test Buffer";
        EDocImplState: Codeunit "E-Doc. Impl. State";
        EDocReceiveFiles: Codeunit "E-Doc. Receive Files";
        Assert: Codeunit Assert;
        NullGuid: Guid;
        GetBasicInfoErr: Label 'Test Get Basic Info From Received Document Error.', Locked = true;
        GetCompleteInfoErr: Label 'Test Get Complete Info From Received Document Error.', Locked = true;

    [Test]
    procedure ReceiveSinglePurchaseInvoice()
    var
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create purchase invoice
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

        PurchaseHeader."Due Date" := WorkDate() + 30;
        PurchaseHeader.Modify();

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();

        CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

        CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
        CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
        if CreatedPurchaseLine.FindSet() then
            repeat
                PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                PurchaseLine.FindFirst();
                CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
            until CreatedPurchaseLine.Next() = 0;

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);

        CreatedPurchaseHeader.SetHideValidationDialog(true);
        CreatedPurchaseHeader."E-Document Link" := NullGuid;
        CreatedPurchaseHeader.Delete(true);
    end;

    [Test]
    procedure ReceiveSinglePurchaseInvoice_PEPPOL_WithAttachment()
    var
        EDocService: Record "E-Document Service";
        Item: Record Item;
        ItemReference: Record "Item Reference";
        DocumentAttachment: Record "Document Attachment";
        TempXMLBuffer: Record "XML Buffer" temporary;
        VATPostingSetup: Record "VAT Posting Setup";
        TempBlob: Codeunit "Temp Blob";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        Document: Text;
        XMLInstream: InStream;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document with two attachments and create purchase invoice
        Initialize();
        BindSubscription(EDocImplState);

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        LibraryPurchase.CreateVendorWithVATRegNo(Vendor);
        LibraryERM.CreateVATPostingSetupWithAccounts(VATPostingSetup, Enum::"Tax Calculation Type"::"Normal VAT", 1);

        // Setup correct vendor VAT and Item Ref to process document
        Vendor."VAT Bus. Posting Group" := VATPostingSetup."VAT Bus. Posting Group";
        Vendor."VAT Registration No." := 'GB123456789';
        Vendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Invoice";
        Vendor."Country/Region Code" := CountryRegion.Code;
        Vendor.Modify();
        Item.FindFirst();
        Item."VAT Prod. Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
        Item.Modify();
        ItemReference.DeleteAll();
        ItemReference."Item No." := Item."No.";
        ItemReference."Reference No." := '1000';
        ItemReference.Insert();

        TempXMLBuffer.LoadFromText(EDocReceiveFiles.GetDocument1());
        TempXMLBuffer.Reset();
        TempXMLBuffer.SetRange(Type, TempXMLBuffer.Type::Element);
        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:EndpointID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := Vendor."VAT Registration No.";
        TempXMLBuffer.Modify();

        TempXMLBuffer.Reset();
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Save(TempBlob);

        TempBlob.CreateInStream(XMLInstream, TextEncoding::UTF8);
        XMLInstream.Read(Document);

        // [GIVEN] We receive PEPPOL XML
        LibraryVariableStorage.Clear();
        LibraryVariableStorage.Enqueue(Document);
        LibraryVariableStorage.Enqueue(1);
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        EDocService."Document Format" := "E-Document Format"::"PEPPOL BIS 3.0";
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Validate Receiving Company" := false;
        EDocService.Modify();

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        Assert.AreEqual(Format(Enum::"E-Document Service Status"::"Imported Document Created"), EDocumentPage.InboundEDocFactbox.Status.Value(), 'Wrong service status for processed document');

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), 'Wrong error message type.');
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), 'Wrong message in error.');

        // Get the purchase invoice from page
        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();
        Assert.RecordCount(CreatedPurchaseHeader, 1);

        DocumentAttachment.SetRange("No.", CreatedPurchaseHeader."No.");
        DocumentAttachment.SetRange("Table ID", Database::"Purchase Header");
        Assert.RecordCount(DocumentAttachment, 2);
    end;

    [Test]
    procedure ReceiveSinglePurchaseInvoice_PEPPOLDataExch_WithAttachment()
    var
        EDocService: Record "E-Document Service";
        Item: Record Item;
        ItemReference: Record "Item Reference";
        DocumentAttachment: Record "Document Attachment";
        EDocServiceDataExchDef: Record "E-Doc. Service Data Exch. Def.";
        TempXMLBuffer: Record "XML Buffer" temporary;
        TempBlob: Codeunit "Temp Blob";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        Document: Text;
        XMLInstream: InStream;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document with two attachments and create purchase invoice
        Initialize();
        BindSubscription(EDocImplState);

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        LibraryPurchase.CreateVendorWithVATRegNo(Vendor);

        // Setup correct vendor VAT and Item Ref to process document
        Vendor."VAT Registration No." := 'GB123456789';
        Vendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Invoice";
        Vendor.Modify();
        Item.FindFirst();
        ItemReference.DeleteAll();
        ItemReference."Item No." := Item."No.";
        ItemReference."Reference No." := '1000';
        ItemReference.Insert();

        EDocService."Document Format" := "E-Document Format"::"Data Exchange";
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Validate Receiving Company" := false;
        EDocService.Modify();

        EDocServiceDataExchDef."E-Document Format Code" := EDocService.Code;
        EDocServiceDataExchDef."Document Type" := EDocServiceDataExchDef."Document Type"::"Purchase Invoice";
        EDocServiceDataExchDef."Impt. Data Exchange Def. Code" := 'EDOCPEPPOLINVIMP';
        EDocServiceDataExchDef.Insert();

        TempXMLBuffer.LoadFromText(EDocReceiveFiles.GetDocument1());
        TempXMLBuffer.Reset();
        TempXMLBuffer.SetRange(Type, TempXMLBuffer.Type::Element);
        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:EndpointID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := Vendor."VAT Registration No.";
        TempXMLBuffer.Modify();

        TempXMLBuffer.Reset();
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Save(TempBlob);

        TempBlob.CreateInStream(XMLInstream, TextEncoding::UTF8);
        XMLInstream.Read(Document);

        // [GIVEN] We receive PEPPOL XML
        LibraryVariableStorage.Clear();
        LibraryVariableStorage.Enqueue(Document);
        LibraryVariableStorage.Enqueue(1);
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        Assert.AreEqual(Format(Enum::"E-Document Service Status"::"Imported Document Created"), EDocumentPage.InboundEDocFactbox.Status.Value(), 'Wrong service status for processed document');

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), 'Wrong error message type.');
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), 'Wrong message in error.');

        // Get the purchase invoice from page
        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();
        Assert.RecordCount(CreatedPurchaseHeader, 1);

        DocumentAttachment.SetRange("No.", CreatedPurchaseHeader."No.");
        DocumentAttachment.SetRange("Table ID", Database::"Purchase Header");
        Assert.RecordCount(DocumentAttachment, 2);

        EDocService."Document Format" := "E-Document Format"::Mock;
        EDocService.Modify();
    end;

    [Test]
    [HandlerFunctions('SelectPOHandlerFirst')]
    procedure ReceiveSinglePurchaseInvoice_PEPPOL_WithAttachment_ToOrder()
    var
        EDocService: Record "E-Document Service";
        EDocument: Record "E-Document";
        Item: Record Item;
        ItemReference: Record "Item Reference";
        DocumentAttachment: Record "Document Attachment";
        TempXMLBuffer: Record "XML Buffer" temporary;
        VATPostingSetup: Record "VAT Posting Setup";
        TempBlob: Codeunit "Temp Blob";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        Document: Text;
        XMLInstream: InStream;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document with two attachments and create purchase invoice
        Initialize();
        BindSubscription(EDocImplState);

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        LibraryPurchase.CreateVendorWithVATRegNo(Vendor);
        LibraryERM.CreateVATPostingSetupWithAccounts(VATPostingSetup, Enum::"Tax Calculation Type"::"Normal VAT", 1);

        // Setup correct vendor VAT and Item Ref to process document
        Vendor."VAT Bus. Posting Group" := VATPostingSetup."VAT Bus. Posting Group";
        Vendor."VAT Registration No." := 'GB123456789';
        Vendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Order";
        Vendor."Country/Region Code" := CountryRegion.Code;
        Vendor.Modify();
        Item.FindFirst();
        Item."VAT Prod. Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
        Item.Modify();
        ItemReference.DeleteAll();
        ItemReference."Item No." := Item."No.";
        ItemReference."Reference No." := '1000';
        ItemReference.Insert();

        TempXMLBuffer.LoadFromText(EDocReceiveFiles.GetDocument1());
        TempXMLBuffer.Reset();
        TempXMLBuffer.SetRange(Type, TempXMLBuffer.Type::Element);
        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:EndpointID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := Vendor."VAT Registration No.";
        TempXMLBuffer.Modify();

        TempXMLBuffer.Reset();
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Save(TempBlob);

        TempBlob.CreateInStream(XMLInstream, TextEncoding::UTF8);
        XMLInstream.Read(Document);

        // [GIVEN] We receive PEPPOL XML
        LibraryVariableStorage.Clear();
        LibraryVariableStorage.Enqueue(Document);
        LibraryVariableStorage.Enqueue(1);
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        EDocService."Document Format" := "E-Document Format"::"PEPPOL BIS 3.0";
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Validate Receiving Company" := false;
        EDocService.Modify();

        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponding values
        EDocument.FindLast();
        EDocumentPage.OpenView();
        EDocumentPage.Filter.SetFilter("Document No.", EDocument."Document No.");

        Assert.AreEqual(Format(Enum::"E-Document Service Status"::"Order Linked"), EDocumentPage.InboundEDocFactbox.Status.Value(), 'Wrong service status for processed document');

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), 'Wrong error message type.');
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), 'Wrong message in error.');

        // [THEN] Attachments are moved to Purchase Header
        DocumentAttachment.SetRange("No.", PurchaseHeader."No.");
        DocumentAttachment.SetRange("Table ID", Database::"Purchase Header");
        DocumentAttachment.SetRange("Document Type", Enum::"Attachment Document Type"::Order);
        DocumentAttachment.SetRange("E-Document Attachment", true);
        Assert.RecordCount(DocumentAttachment, 2);
    end;

    [Test]
    [HandlerFunctions('SelectPOHandler')]
    procedure ReceiveToPurchaseOrderLink()
    var
        Vendor1: Record Vendor;
        EDocService: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocument: Record "E-Document";
        EDocServicePage: TestPage "E-Document Service";
        OrderNo: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Link to existing Purchase Order for vendor
        Initialize();

        // [GIVEN] E-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Document Format" := Enum::"E-Document Format"::Mock;
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor1);
        Vendor1."Receive E-Document To" := Vendor1."Receive E-Document To"::"Purchase Order";
        Vendor1.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor1."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);
        OrderNo := PurchaseHeader."No.";
        LibraryVariableStorage.Enqueue(PurchaseHeader);

        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor1."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Page to pick Purchase Order appears
        // Handler function

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchaseHeader.SetRange("No.", OrderNo);
        PurchaseHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseHeader.FindLast();
        EDocServiceStatus.FindLast();

        Assert.AreEqual(PurchaseHeader."No.", EDocument."Order No.", '');
        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, '');
        Assert.AreEqual(PurchaseHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreEqual(EDocument.SystemId, PurchaseHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Order Linked", EDocServiceStatus.Status, '');
    end;

    [Test]
    procedure ReceiveToPurchaseOrderLinkWithOrderNo()
    var
        EDocService: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocument: Record "E-Document";
        EDocServicePage: TestPage "E-Document Service";
        OrderNo: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Link two invoices to existing Purchase Order for vendor
        Initialize();

        // [GIVEN] E-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Order";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);
        OrderNo := PurchaseHeader."No.";
        LibraryVariableStorage.Enqueue(PurchaseHeader);

        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        PurchOrderTestBuffer.SetEDocOrderNo(CopyStr(OrderNo, 1, 20));

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchaseHeader.SetRange("No.", OrderNo);
        PurchaseHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseHeader.FindLast();
        EDocServiceStatus.FindLast();

        Assert.AreEqual(PurchaseHeader."No.", EDocument."Order No.", '');
        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, '');
        Assert.AreEqual(PurchaseHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreEqual(EDocument.SystemId, PurchaseHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Order Linked", EDocServiceStatus.Status, '');

        // [GIVEN] One more invoice is received to PO
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        PurchOrderTestBuffer.SetEDocOrderNo(CopyStr(OrderNo, 1, 20));

        // [WHEN] Running Receive
        EDocServicePage.Receive.Invoke();

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchaseHeader.SetRange("No.", OrderNo);
        PurchaseHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseHeader.FindLast();
        EDocServiceStatus.FindLast();

        Assert.AreEqual(PurchaseHeader."No.", EDocument."Order No.", '');
        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, '');
        Assert.AreEqual(PurchaseHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreNotEqual(EDocument.SystemId, PurchaseHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Pending", EDocServiceStatus.Status, '');
    end;

    [Test]
    [HandlerFunctions('SelectPOHandlerCancel')]
    procedure ReceiveToPurchaseOrderCreated()
    var
        PurchHeader: Record "Purchase Header";
        EDocService: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocument: Record "E-Document";
        EDocServicePage: TestPage "E-Document Service";
        OrderNo: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Link to Purchase Order where user click cancel to link
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Order";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);
        OrderNo := PurchHeader."No.";
        LibraryVariableStorage.Enqueue(PurchHeader);

        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Invoice, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Page to pick Purchase Order appears
        // Handler functions

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchHeader.FindLast();
        EDocServiceStatus.FindLast();
        // PurchaseHeader.SetRange("No.", OrderNo);

        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::Processed, EDocument.Status, '');
        Assert.AreEqual(PurchHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreEqual(EDocument.SystemId, PurchHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Imported Document Created", EDocServiceStatus.Status, '');
    end;

    [Test]
    procedure ReceiveFivePurchaseInvoices()
    var
        EDocument: Record "E-Document";
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        i, j, LastEDocNo : Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multimple e-documents in one file and create multiple purchase invoices
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase invoices
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] multiple purchase invoices
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // Finding current last eDocument entry number
        EDocument.Reset();
        if EDocument.FindLast() then
            LastEDocNo := EDocument."Entry No";

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] 5 electronic documents are created
        EDocument.SetFilter("Entry No", '>%1', LastEDocNo);
        Assert.AreEqual(5, EDocument.Count(), '');
        // [THEN] Purchase invoices are created with corresponfing values
        if EDocument.FindSet() then
            repeat
                CreatedPurchaseHeader.Reset();
                CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
                CreatedPurchaseHeader.SetRange("No.", EDocument."Document No.");
                CreatedPurchaseHeader.FindFirst();

                PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, CreatedPurchaseHeader."Vendor Invoice No.");

                CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

                CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
                CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
                if CreatedPurchaseLine.FindSet() then
                    repeat
                        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                        PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                        PurchaseLine.FindFirst();
                        CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
                    until CreatedPurchaseLine.Next() = 0;

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                CreatedPurchaseHeader.SetHideValidationDialog(true);
                CreatedPurchaseHeader."E-Document Link" := NullGuid;
                CreatedPurchaseHeader.Delete(true);
            until EDocument.Next() = 0;
    end;

    [Test]
    procedure ReceiveSinglePurchaseCreditMemo()
    var
        EDocService: Record "E-Document Service";
        EDocReceiveTest: Codeunit "E-Doc. Receive Test";
        EnvironmentInformation: Codeunit "Environment Information";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
        Country: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create purchase credit memo
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase credit memo
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase credit memo
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        Country := EnvironmentInformation.GetApplicationFamily();
        if Country = 'ES' then
            BindSubscription(EDocReceiveTest);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        if Country = 'ES' then
            UnbindSubscription(EDocReceiveTest);

        // [THEN] Purchase credit memo is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::"Credit Memo");
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();

        CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

        CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
        CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
        if CreatedPurchaseLine.FindSet() then
            repeat
                PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                PurchaseLine.FindFirst();
                CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
            until CreatedPurchaseLine.Next() = 0;

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);

        CreatedPurchaseHeader.SetHideValidationDialog(true);
        CreatedPurchaseHeader."E-Document Link" := NullGuid;
        CreatedPurchaseHeader.Delete(true);
    end;

    [Test]
    procedure ReceiveFivePurchaseCreditMemos()
    var
        EDocument: Record "E-Document";
        EDocService: Record "E-Document Service";
        EDocReceiveTest: Codeunit "E-Doc. Receive Test";
        EnvironmentInformation: Codeunit "Environment Information";
        EDocServicePage: TestPage "E-Document Service";
        i, j, LastEDocNo : Integer;
        Country: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multiple e-documents in one file and create multiple purchase credit memos
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase credit memos
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] purchase credit memo
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // Finding current last eDocument entry number
        EDocument.Reset();
        if EDocument.FindLast() then
            LastEDocNo := EDocument."Entry No";

        Country := EnvironmentInformation.GetApplicationFamily();
        if Country = 'ES' then
            BindSubscription(EDocReceiveTest);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        if Country = 'ES' then
            UnbindSubscription(EDocReceiveTest);

        // [THEN] 5 electronic documents are created
        EDocument.SetFilter("Entry No", '>%1', LastEDocNo);
        Assert.AreEqual(5, EDocument.Count(), '');
        // [THEN] Purchase credit memos are created with corresponfing values
        if EDocument.FindSet() then
            repeat
                CreatedPurchaseHeader.Reset();
                CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::"Credit Memo");
                CreatedPurchaseHeader.SetRange("No.", EDocument."Document No.");
                CreatedPurchaseHeader.FindFirst();

                PurchaseHeader.Get(PurchaseHeader."Document Type"::"Credit Memo", CreatedPurchaseHeader."Vendor Invoice No.");

                CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

                CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
                CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
                if CreatedPurchaseLine.FindSet() then
                    repeat
                        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                        PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                        PurchaseLine.FindFirst();
                        CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
                    until CreatedPurchaseLine.Next() = 0;

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                CreatedPurchaseHeader.SetHideValidationDialog(true);
                CreatedPurchaseHeader."E-Document Link" := NullGuid;
                CreatedPurchaseHeader.Delete(true);
            until EDocument.Next() = 0;
    end;

    [Test]
    procedure ReceiveSinglePurchaseInvoiceToJournal()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create journal line
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Debit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
        PurchaseHeader."Pay-to Name" := 'Journal Test Invoice';
        PurchaseHeader.Modify();

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal line is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        GenJnlLine.SetRange("Document No.", EDocumentPage."Document No.".Value());
        GenJnlLine.FindFirst();

        CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
        GenJnlLine.Delete(true);
        GenJnlBatch.Delete(true);
    end;

    [Test]
    procedure ReceiveMultiPurchaseInvoicesToJournal()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        i, j : Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multiple e-documents and create multiple journal lines
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase invoices
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Debit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] purchase invoices
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
            PurchaseHeader."Pay-to Name" := 'Journal Test Invoice no. ' + Format(i);
            PurchaseHeader.Modify();

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal lines are created with corresponfing values
        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        if GenJnlLine.FindSet() then
            repeat
                PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Invoice);
                PurchaseHeader.SetRange("Vendor Invoice No.", GenJnlLine."External Document No.");
                PurchaseHeader.FindFirst();

                CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                GenJnlLine.Delete(true);
            until GenJnlLine.Next() = 0;
    end;

    [Test]
    procedure ReceiveSinglePurchaseCreditMemoToJournal()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create journal line
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase credit memo
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Credit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        // [GIVEN] purchase credit memo
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");
        PurchaseHeader."Pay-to Name" := 'Journal Test Invoice';
        PurchaseHeader.Modify();

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal line is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        GenJnlLine.SetRange("Document No.", EDocumentPage."Document No.".Value());
        GenJnlLine.FindFirst();

        CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
        GenJnlLine.Delete(true);
        GenJnlBatch.Delete(true);
    end;

    [Test]
    procedure ReceiveMultiCreditMemosToJournal()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        i, j : Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multiple e-documents and create multiple journal lines
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase credit memos
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Credit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] purchase credit memos
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");
            PurchaseHeader."Pay-to Name" := 'Journal Test Invoice no. ' + Format(i);
            PurchaseHeader.Modify();

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal lines are created with corresponfing values
        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        if GenJnlLine.FindSet() then
            repeat
                PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::"Credit Memo");
                PurchaseHeader.SetRange("Vendor Cr. Memo No.", GenJnlLine."External Document No.");
                PurchaseHeader.FindFirst();

                CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                GenJnlLine.Delete(true);
            until GenJnlLine.Next() = 0;
    end;

    [Test]
    procedure GetBasicInfoFromReceivedDocumentError()
    var
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and try to get besic info
        Initialize();

        // [GIVEN] e-Document service to raised receiving error
        LibraryEDoc.CreateGetBasicInfoErrorReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowBasicInfoError();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();
        Assert.AreEqual(GetBasicInfoErr, EDocumentPage.ErrorMessagesPart.Description.Value(), '');

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
    end;

    [Test]
    procedure GetCompleteInfoFromReceivedDocumentError()
    var
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and try to get besic info
        Initialize();

        // [GIVEN] e-Document service to raised receiving error
        LibraryEDoc.CreateGetCompleteInfoErrorReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::"Mock");
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowCompleteInfoError();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();
        Assert.AreEqual(GetCompleteInfoErr, EDocumentPage.ErrorMessagesPart.Description.Value(), '');

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure ReceiveEDocumentDuplicate()
    var
        EDocService: Record "E-Document Service";
        EDocument: Record "E-Document";
        EDocument2: Record "E-Document";
        Item: Record Item;
        VATPostingSetup: Record "VAT Posting Setup";
        DocumentVendor: Record Vendor;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive e-document twice so the duplicate will be skipped in creation
        Initialize();
        BindSubscription(EDocImplState);

        // [GIVEN] e-Document service to receive one single purchase order
        CreateEDocServiceToReceivePurchaseOrder(EDocService);
        // [GIVEN] Vendor with VAT Posting Setup
        CreateVendorWithVatPostingSetup(DocumentVendor, VATPostingSetup);
        // [GIVEN] Item with item reference
        CreateItemWithReference(Item, VATPostingSetup);
        // [GIVEN] Incoming PEPPOL duplicated document
        CreateIncomingDuplicatedPEPPOL(DocumentVendor);

        // [WHEN] Running Receive
        InvokeReceive(EDocService);

        // [THEN] Only one E-Document is created
        EDocument.FindLast();
        EDocument2.SetRange("Bill-to/Pay-to No.", EDocument."Bill-to/Pay-to No.");
        EDocument2.SetRange("Incoming E-Document No.", EDocument."Incoming E-Document No.");
        EDocument2.SetRange("Document Date", EDocument."Document Date");
        EDocument2.SetFilter("Entry No", '<>%1', EDocument."Entry No");
        Assert.IsTrue(EDocument2.IsEmpty(), 'Duplicate E-Document created.');
    end;

    [ModalPageHandler]
    procedure SelectPOHandler(var POList: TestPage "Purchase Order List")
    var
        Variant: Variant;
    begin
        LibraryVariableStorage.Dequeue(Variant);
        POList.GoToRecord(Variant);
        POList.OK().Invoke();
    end;

    [ModalPageHandler]
    procedure SelectPOHandlerFirst(var POList: TestPage "Purchase Order List")
    begin
        POList.First();
        POList.OK().Invoke();
    end;

    [ModalPageHandler]
    procedure SelectPOHandlerCancel(var POList: TestPage "Purchase Order List")
    begin
        POList.Cancel().Invoke();
    end;


    [ConfirmHandler]
    procedure ConfirmHandlerYes(Message: Text[1024]; var Reply: Boolean)
    begin
        Reply := true;
    end;

    [ConfirmHandler]
    procedure ConfirmHandler(Message: Text[1024]; var Reply: Boolean)
    begin
        Reply := false;
    end;

    [StrMenuHandler]
    procedure MenuHandler(Options: Text[1024]; var Choice: Integer; Instruction: Text[1024])
    begin
    end;

    [MessageHandler]
    procedure MessageHandler(Message: Text[1024])
    begin
    end;

    local procedure Initialize()
    var
        DocumentAttachment: Record "Document Attachment";
        EDocument: Record "E-Document";
    begin
        Clear(EDocImplState);
        Clear(PurchaseHeader);
        Clear(LibraryVariableStorage);
        PurchaseHeader.DeleteAll();
        DocumentAttachment.DeleteAll();

        Vendor.SetRange("VAT Registration No.", 'GB123456789');
        Vendor.DeleteAll();
        EDocument.DeleteAll();
        LibraryERM.FindCountryRegion(CountryRegion);
    end;

    local procedure CheckPurchaseHeadersAreEqual(var PurchHeader1: Record "Purchase Header"; var PurchHeader2: Record "Purchase Header")
    begin
        Assert.AreEqual(PurchHeader1."Pay-to Vendor No.", PurchHeader2."Pay-to Vendor No.", '');
        Assert.AreEqual(PurchHeader1."Pay-to Name", PurchHeader2."Pay-to Name", '');
        Assert.AreEqual(PurchHeader1."Pay-to Address", PurchHeader2."Pay-to Address", '');
        Assert.AreEqual(PurchHeader1."Document Date", PurchHeader2."Document Date", '');
        Assert.AreEqual(PurchHeader1."Due Date", PurchHeader2."Due Date", '');
        Assert.AreEqual(PurchHeader1."No.", PurchHeader2."Vendor Invoice No.", '');

        PurchHeader1.CalcFields(Amount, "Amount Including VAT");
        CreatedPurchaseHeader.CalcFields(Amount, "Amount Including VAT");
        Assert.AreEqual(PurchHeader1.Amount, PurchHeader2.Amount, '');
        Assert.AreEqual(PurchHeader1."Amount Including VAT", PurchHeader2."Amount Including VAT", '');
    end;

    local procedure CheckPurchaseLinesAreEqual(var PurchLine1: Record "Purchase Line"; var PurchLine2: Record "Purchase Line")
    begin
        Assert.AreEqual(PurchLine1.Type, PurchLine2.Type, '');
        Assert.AreEqual(PurchLine1."No.", PurchLine2."No.", '');
        Assert.AreEqual(PurchLine1.Description, PurchLine2.Description, '');
        Assert.AreEqual(PurchLine1.Quantity, PurchLine2.Quantity, '');
        Assert.AreEqual(PurchLine1."Direct Unit Cost", PurchLine2."Direct Unit Cost", '');
        Assert.AreEqual(PurchLine1."Line Amount", PurchLine2."Line Amount", '');
    end;

    local procedure CheckGenJnlLineIsEqualToPurchaseHeader(var PurchHeader: Record "Purchase Header"; var GenJnlLine: Record "Gen. Journal Line")
    begin
        Assert.AreEqual(PurchHeader."Document Type", GenJnlLine."Document Type", '');
        Assert.AreEqual(GenJnlLine."Bal. Account Type"::Vendor, GenJnlLine."Bal. Account Type", '');
        Assert.AreEqual(PurchHeader."Pay-to Vendor No.", GenJnlLine."Bal. Account No.", '');
        Assert.AreEqual(PurchHeader."Pay-to Name", GenJnlLine.Description, '');
        Assert.AreEqual(PurchHeader."Document Date", GenJnlLine."Document Date", '');
        Assert.AreEqual(PurchHeader."Due Date", GenJnlLine."Due Date", '');

        PurchHeader.CalcFields("Amount Including VAT");
        Assert.AreEqual(PurchHeader."Amount Including VAT", Abs(GenJnlLine.Amount), '');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Document Create Purch. Doc.", 'OnBeforeProcessHeaderFieldsAssignment', '', false, false)]
    local procedure OnBeforeProcessHeaderFieldsAssignment(var DocumentHeader: RecordRef; var PurchaseField: Record Field);
    begin
        PurchaseField.SetRange("No.", 10705);
    end;

    local procedure CreateEDocServiceToReceivePurchaseOrder(var EDocService: Record "E-Document Service")
    begin
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"Service Integration"::Mock);
        SetDefaultEDocServiceValues(EDocService);
    end;

    local procedure CreateVendorWithVatPostingSetup(var DocumentVendor: Record Vendor; var VATPostingSetup: Record "VAT Posting Setup")
    begin
        LibraryPurchase.CreateVendorWithVATRegNo(DocumentVendor);
        LibraryERM.CreateVATPostingSetupWithAccounts(VATPostingSetup, Enum::"Tax Calculation Type"::"Normal VAT", 1);
        DocumentVendor."VAT Bus. Posting Group" := VATPostingSetup."VAT Bus. Posting Group";
        DocumentVendor."VAT Registration No." := 'GB123456789';
        DocumentVendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Order";
        DocumentVendor."Country/Region Code" := CountryRegion.Code;
        DocumentVendor.Modify(false);
    end;

    local procedure CreateItemWithReference(var Item: Record Item; var VATPostingSetup: Record "VAT Posting Setup")
    var
        ItemReference: Record "Item Reference";
    begin
        Item.FindFirst();
        Item."VAT Prod. Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
        Item.Modify(false);
        ItemReference.DeleteAll(false);
        ItemReference."Item No." := Item."No.";
        ItemReference."Reference No." := '1000';
        ItemReference.Insert(false);
    end;

    local procedure CreateIncomingDuplicatedPEPPOL(var DocumentVendor: Record Vendor)
    var
        TempXMLBuffer: Record "XML Buffer" temporary;
        TempBlob: Codeunit "Temp Blob";
        Document: Text;
        XMLInstream: InStream;
    begin
        TempXMLBuffer.LoadFromText(EDocReceiveFiles.GetDocument1());
        TempXMLBuffer.Reset();
        TempXMLBuffer.SetRange(Type, TempXMLBuffer.Type::Element);
        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:EndpointID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := DocumentVendor."VAT Registration No.";
        TempXMLBuffer.Modify();

        TempXMLBuffer.SetRange(Path, '/Invoice/cbc:ID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := LibraryRandom.RandText(20);

        TempXMLBuffer.Reset();
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Save(TempBlob);

        TempBlob.CreateInStream(XMLInstream, TextEncoding::UTF8);
        XMLInstream.Read(Document);

        LibraryVariableStorage.Clear();
        LibraryVariableStorage.Enqueue(Document);
        LibraryVariableStorage.Enqueue(2);
        EDocImplState.SetVariableStorage(LibraryVariableStorage);
    end;

    local procedure InvokeReceive(var EDocService: Record "E-Document Service")
    var
        EDocServicePage: TestPage "E-Document Service";
    begin
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();
    end;

    local procedure SetDefaultEDocServiceValues(var EDocService: Record "E-Document Service")
    begin
        EDocService."Document Format" := "E-Document Format"::"PEPPOL BIS 3.0";
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Validate Receiving Company" := false;
        EDocService.Modify(false);
    end;

#if not CLEAN26
#pragma warning disable AL0432
    // Tests inside CLEAN26 are testing the interfaces that is to be removed when CLEAN26 tags are removed.
    // Until then, the tests are kept.

    [Test]
    internal procedure ReceiveSinglePurchaseInvoice26()
    var
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create purchase invoice
        Initialize();
        EDocService.DeleteAll();

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();

        CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

        CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
        CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
        if CreatedPurchaseLine.FindSet() then
            repeat
                PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                PurchaseLine.FindFirst();
                CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
            until CreatedPurchaseLine.Next() = 0;

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);

        CreatedPurchaseHeader.SetHideValidationDialog(true);
        CreatedPurchaseHeader."E-Document Link" := NullGuid;
        CreatedPurchaseHeader.Delete(true);
    end;

    [Test]
    internal procedure ReceiveSinglePurchaseInvoice_PEPPOL_WithAttachment26()
    var
        EDocService: Record "E-Document Service";
        Item: Record Item;
        ItemReference: Record "Item Reference";
        DocumentAttachment: Record "Document Attachment";
        TempXMLBuffer: Record "XML Buffer" temporary;
        VATPostingSetup: Record "VAT Posting Setup";
        TempBlob: Codeunit "Temp Blob";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        Document: Text;
        XMLInstream: InStream;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document with two attachments and create purchase invoice
        Initialize();
        BindSubscription(EDocImplState);

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        LibraryPurchase.CreateVendorWithVATRegNo(Vendor);
        LibraryERM.CreateVATPostingSetupWithAccounts(VATPostingSetup, Enum::"Tax Calculation Type"::"Normal VAT", 1);

        // Setup correct vendor VAT and Item Ref to process document
        Vendor."VAT Bus. Posting Group" := VATPostingSetup."VAT Bus. Posting Group";
        Vendor."VAT Registration No." := 'GB123456789';
        Vendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Invoice";
        Vendor."Country/Region Code" := CountryRegion.Code;
        Vendor.Modify();
        Item.FindFirst();
        Item."VAT Prod. Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
        Item.Modify();
        ItemReference.DeleteAll();
        ItemReference."Item No." := Item."No.";
        ItemReference."Reference No." := '1000';
        ItemReference.Insert();

        TempXMLBuffer.LoadFromText(EDocReceiveFiles.GetDocument1());
        TempXMLBuffer.Reset();
        TempXMLBuffer.SetRange(Type, TempXMLBuffer.Type::Element);
        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:EndpointID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := Vendor."VAT Registration No.";
        TempXMLBuffer.Modify();

        TempXMLBuffer.Reset();
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Save(TempBlob);

        TempBlob.CreateInStream(XMLInstream, TextEncoding::UTF8);
        XMLInstream.Read(Document);

        // [GIVEN] We receive PEPPOL XML
        LibraryVariableStorage.Clear();
        LibraryVariableStorage.Enqueue(Document);
        LibraryVariableStorage.Enqueue(1);
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        EDocService."Document Format" := "E-Document Format"::"PEPPOL BIS 3.0";
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Validate Receiving Company" := false;
        EDocService.Modify();

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        Assert.AreEqual(Format(Enum::"E-Document Service Status"::"Imported Document Created"), EDocumentPage.InboundEDocFactbox.Status.Value(), 'Wrong service status for processed document');

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), 'Wrong error message type.');
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), 'Wrong message in error.');

        // Get the purchase invoice from page
        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();
        Assert.RecordCount(CreatedPurchaseHeader, 1);

        DocumentAttachment.SetRange("No.", CreatedPurchaseHeader."No.");
        DocumentAttachment.SetRange("Table ID", Database::"Purchase Header");
        Assert.RecordCount(DocumentAttachment, 2);
    end;

    [Test]
    internal procedure ReceiveSinglePurchaseInvoice_PEPPOLDataExch_WithAttachment26()
    var
        EDocService: Record "E-Document Service";
        Item: Record Item;
        ItemReference: Record "Item Reference";
        DocumentAttachment: Record "Document Attachment";
        EDocServiceDataExchDef: Record "E-Doc. Service Data Exch. Def.";
        TempXMLBuffer: Record "XML Buffer" temporary;
        TempBlob: Codeunit "Temp Blob";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        Document: Text;
        XMLInstream: InStream;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document with two attachments and create purchase invoice
        Initialize();
        BindSubscription(EDocImplState);

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        LibraryPurchase.CreateVendorWithVATRegNo(Vendor);

        // Setup correct vendor VAT and Item Ref to process document
        Vendor."VAT Registration No." := 'GB123456789';
        Vendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Invoice";
        Vendor.Modify();
        Item.FindFirst();
        ItemReference.DeleteAll();
        ItemReference."Item No." := Item."No.";
        ItemReference."Reference No." := '1000';
        ItemReference.Insert();

        EDocService."Document Format" := "E-Document Format"::"Data Exchange";
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Validate Receiving Company" := false;
        EDocService.Modify();

        EDocServiceDataExchDef."E-Document Format Code" := EDocService.Code;
        EDocServiceDataExchDef."Document Type" := EDocServiceDataExchDef."Document Type"::"Purchase Invoice";
        EDocServiceDataExchDef."Impt. Data Exchange Def. Code" := 'EDOCPEPPOLINVIMP';
        if EDocServiceDataExchDef.Insert() then;

        TempXMLBuffer.LoadFromText(EDocReceiveFiles.GetDocument1());
        TempXMLBuffer.Reset();
        TempXMLBuffer.SetRange(Type, TempXMLBuffer.Type::Element);
        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:EndpointID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := Vendor."VAT Registration No.";
        TempXMLBuffer.Modify();

        TempXMLBuffer.Reset();
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Save(TempBlob);

        TempBlob.CreateInStream(XMLInstream, TextEncoding::UTF8);
        XMLInstream.Read(Document);

        // [GIVEN] We receive PEPPOL XML
        LibraryVariableStorage.Clear();
        LibraryVariableStorage.Enqueue(Document);
        LibraryVariableStorage.Enqueue(1);
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        Assert.AreEqual(Format(Enum::"E-Document Service Status"::"Imported Document Created"), EDocumentPage.InboundEDocFactbox.Status.Value(), 'Wrong service status for processed document');

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), 'Wrong error message type.');
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), 'Wrong message in error.');

        // Get the purchase invoice from page
        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();
        Assert.RecordCount(CreatedPurchaseHeader, 1);

        DocumentAttachment.SetRange("No.", CreatedPurchaseHeader."No.");
        DocumentAttachment.SetRange("Table ID", Database::"Purchase Header");
        Assert.RecordCount(DocumentAttachment, 2);

        EDocService."Document Format" := "E-Document Format"::Mock;
        EDocService.Modify();
    end;

    [Test]
    [HandlerFunctions('SelectPOHandlerFirst')]
    internal procedure ReceiveSinglePurchaseInvoice_PEPPOL_WithAttachment_ToOrder26()
    var
        EDocService: Record "E-Document Service";
        EDocument: Record "E-Document";
        Item: Record Item;
        ItemReference: Record "Item Reference";
        DocumentAttachment: Record "Document Attachment";
        TempXMLBuffer: Record "XML Buffer" temporary;
        VATPostingSetup: Record "VAT Posting Setup";
        TempBlob: Codeunit "Temp Blob";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        Document: Text;
        XMLInstream: InStream;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document with two attachments and create purchase invoice
        Initialize();
        BindSubscription(EDocImplState);

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        LibraryPurchase.CreateVendorWithVATRegNo(Vendor);
        LibraryERM.CreateVATPostingSetupWithAccounts(VATPostingSetup, Enum::"Tax Calculation Type"::"Normal VAT", 1);

        // Setup correct vendor VAT and Item Ref to process document
        Vendor."VAT Bus. Posting Group" := VATPostingSetup."VAT Bus. Posting Group";
        Vendor."VAT Registration No." := 'GB123456789';
        Vendor."Receive E-Document To" := Enum::"E-Document Type"::"Purchase Order";
        Vendor."Country/Region Code" := CountryRegion.Code;
        Vendor.Modify();
        Item.FindFirst();
        Item."VAT Prod. Posting Group" := VATPostingSetup."VAT Prod. Posting Group";
        Item.Modify();
        ItemReference.DeleteAll();
        ItemReference."Item No." := Item."No.";
        ItemReference."Reference No." := '1000';
        ItemReference.Insert();

        TempXMLBuffer.LoadFromText(EDocReceiveFiles.GetDocument1());
        TempXMLBuffer.Reset();
        TempXMLBuffer.SetRange(Type, TempXMLBuffer.Type::Element);
        TempXMLBuffer.SetRange(Path, '/Invoice/cac:AccountingSupplierParty/cac:Party/cbc:EndpointID');
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Value := Vendor."VAT Registration No.";
        TempXMLBuffer.Modify();

        TempXMLBuffer.Reset();
        TempXMLBuffer.FindFirst();
        TempXMLBuffer.Save(TempBlob);

        TempBlob.CreateInStream(XMLInstream, TextEncoding::UTF8);
        XMLInstream.Read(Document);

        // [GIVEN] We receive PEPPOL XML
        LibraryVariableStorage.Clear();
        LibraryVariableStorage.Enqueue(Document);
        LibraryVariableStorage.Enqueue(1);
        EDocImplState.SetVariableStorage(LibraryVariableStorage);

        EDocService."Document Format" := "E-Document Format"::"PEPPOL BIS 3.0";
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Validate Receiving Company" := false;
        EDocService.Modify();

        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, Item."No.", 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocument.FindLast();
        EDocumentPage.OpenView();
        EDocumentPage.Filter.SetFilter("Document No.", EDocument."Document No.");

        Assert.AreEqual(Format(Enum::"E-Document Service Status"::"Order Linked"), EDocumentPage.InboundEDocFactbox.Status.Value(), 'Wrong service status for processed document');

        // [THEN] E-Document Errors and Warnings has correct status
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart."Message Type".Value(), 'Wrong error message type.');
        Assert.AreEqual('', EDocumentPage.ErrorMessagesPart.Description.Value(), 'Wrong message in error.');

        // [THEN] Attachments are moved to Purchase Header
        DocumentAttachment.SetRange("No.", PurchaseHeader."No.");
        DocumentAttachment.SetRange("Table ID", Database::"Purchase Header");
        DocumentAttachment.SetRange("Document Type", Enum::"Attachment Document Type"::Order);
        DocumentAttachment.SetRange("E-Document Attachment", true);
        Assert.RecordCount(DocumentAttachment, 2);
    end;

    [Test]
    [HandlerFunctions('SelectPOHandler')]
    internal procedure ReceiveToPurchaseOrderLink26()
    var
        Vendor1: Record Vendor;
        EDocService: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocument: Record "E-Document";
        EDocServicePage: TestPage "E-Document Service";
        OrderNo: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Link to existing Purchase Order for vendor
        Initialize();

        // [GIVEN] E-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Document Format" := Enum::"E-Document Format"::Mock;
        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor1);
        Vendor1."Receive E-Document To" := Vendor1."Receive E-Document To"::"Purchase Order";
        Vendor1.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor1."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);
        OrderNo := PurchaseHeader."No.";
        LibraryVariableStorage.Enqueue(PurchaseHeader);

        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor1."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Page to pick Purchase Order appears
        // Handler function

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchaseHeader.SetRange("No.", OrderNo);
        PurchaseHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseHeader.FindLast();
        EDocServiceStatus.FindLast();

        Assert.AreEqual(PurchaseHeader."No.", EDocument."Order No.", '');
        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, '');
        Assert.AreEqual(PurchaseHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreEqual(EDocument.SystemId, PurchaseHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Order Linked", EDocServiceStatus.Status, '');
    end;

    [Test]
    internal procedure ReceiveToPurchaseOrderLinkWithOrderNo26()
    var
        EDocService: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocument: Record "E-Document";
        EDocServicePage: TestPage "E-Document Service";
        OrderNo: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Link two invoices to existing Purchase Order for vendor
        Initialize();

        // [GIVEN] E-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Order";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);
        OrderNo := PurchaseHeader."No.";
        LibraryVariableStorage.Enqueue(PurchaseHeader);

        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        PurchOrderTestBuffer.SetEDocOrderNo(CopyStr(OrderNo, 1, 20));

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchaseHeader.SetRange("No.", OrderNo);
        PurchaseHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseHeader.FindLast();
        EDocServiceStatus.FindLast();

        Assert.AreEqual(PurchaseHeader."No.", EDocument."Order No.", '');
        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, '');
        Assert.AreEqual(PurchaseHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreEqual(EDocument.SystemId, PurchaseHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Order Linked", EDocServiceStatus.Status, '');

        // [GIVEN] One more invoice is received to PO
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        PurchOrderTestBuffer.SetEDocOrderNo(CopyStr(OrderNo, 1, 20));

        // [WHEN] Running Receive
        EDocServicePage.Receive.Invoke();

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchaseHeader.SetRange("No.", OrderNo);
        PurchaseHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseHeader.FindLast();
        EDocServiceStatus.FindLast();

        Assert.AreEqual(PurchaseHeader."No.", EDocument."Order No.", '');
        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::"In Progress", EDocument.Status, '');
        Assert.AreEqual(PurchaseHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreNotEqual(EDocument.SystemId, PurchaseHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Pending", EDocServiceStatus.Status, '');
    end;

    [Test]
    [HandlerFunctions('SelectPOHandlerCancel')]
    internal procedure ReceiveToPurchaseOrderCreated26()
    var
        PurchHeader: Record "Purchase Header";
        EDocService: Record "E-Document Service";
        EDocServiceStatus: Record "E-Document Service Status";
        EDocument: Record "E-Document";
        EDocServicePage: TestPage "E-Document Service";
        OrderNo: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Link to Purchase Order where user click cancel to link
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Order";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Order, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);
        OrderNo := PurchHeader."No.";
        LibraryVariableStorage.Enqueue(PurchHeader);

        LibraryPurchase.CreatePurchHeader(PurchHeader, PurchHeader."Document Type"::Invoice, Vendor."No.");
        LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), 10);
        PurchaseLine.Validate("Direct Unit Cost", 100);
        PurchaseLine.Modify(true);

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Page to pick Purchase Order appears
        // Handler functions

        // [THEN] After processing, check fields
        EDocument.FindLast();
        PurchHeader.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchHeader.FindLast();
        EDocServiceStatus.FindLast();
        // PurchaseHeader.SetRange("No.", OrderNo);

        Assert.AreEqual(Enum::"E-Document Type"::"Purchase Order", EDocument."Document Type", '');
        Assert.AreEqual(Enum::"E-Document Status"::Processed, EDocument.Status, '');
        Assert.AreEqual(PurchHeader.RecordId(), EDocument."Document Record ID", '');
        Assert.AreEqual(EDocument.SystemId, PurchHeader."E-Document Link", '');

        Assert.AreEqual(EDocument."Entry No", EDocServiceStatus."E-Document Entry No", '');
        Assert.AreEqual(Enum::"E-Document Service Status"::"Imported Document Created", EDocServiceStatus.Status, '');
    end;

    [Test]
    internal procedure ReceiveFivePurchaseInvoices26()
    var
        EDocument: Record "E-Document";
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        i, j, LastEDocNo : Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multimple e-documents in one file and create multiple purchase invoices
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase invoices
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] multiple purchase invoices
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // Finding current last eDocument entry number
        EDocument.Reset();
        if EDocument.FindLast() then
            LastEDocNo := EDocument."Entry No";

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] 5 electronic documents are created
        EDocument.SetFilter("Entry No", '>%1', LastEDocNo);
        Assert.AreEqual(5, EDocument.Count(), '');
        // [THEN] Purchase invoices are created with corresponfing values
        if EDocument.FindSet() then
            repeat
                CreatedPurchaseHeader.Reset();
                CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::Invoice);
                CreatedPurchaseHeader.SetRange("No.", EDocument."Document No.");
                CreatedPurchaseHeader.FindFirst();

                PurchaseHeader.Get(PurchaseHeader."Document Type"::Invoice, CreatedPurchaseHeader."Vendor Invoice No.");

                CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

                CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
                CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
                if CreatedPurchaseLine.FindSet() then
                    repeat
                        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                        PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                        PurchaseLine.FindFirst();
                        CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
                    until CreatedPurchaseLine.Next() = 0;

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                CreatedPurchaseHeader.SetHideValidationDialog(true);
                CreatedPurchaseHeader."E-Document Link" := NullGuid;
                CreatedPurchaseHeader.Delete(true);
            until EDocument.Next() = 0;
    end;

    [Test]
    internal procedure ReceiveSinglePurchaseCreditMemo26()
    var
        EDocService: Record "E-Document Service";
        EDocReceiveTest: Codeunit "E-Doc. Receive Test";
        EnvironmentInformation: Codeunit "Environment Information";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
        Country: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create purchase credit memo
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase credit memo
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService.Modify();

        // [GIVEN] purchase credit memo
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        Country := EnvironmentInformation.GetApplicationFamily();
        if Country = 'ES' then
            BindSubscription(EDocReceiveTest);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        if Country = 'ES' then
            UnbindSubscription(EDocReceiveTest);

        // [THEN] Purchase credit memo is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        CreatedPurchaseHeader.Reset();
        CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::"Credit Memo");
        CreatedPurchaseHeader.SetRange("No.", EDocumentPage."Document No.".Value);
        CreatedPurchaseHeader.FindFirst();

        CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

        CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
        CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
        if CreatedPurchaseLine.FindSet() then
            repeat
                PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                PurchaseLine.FindFirst();
                CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
            until CreatedPurchaseLine.Next() = 0;

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);

        CreatedPurchaseHeader.SetHideValidationDialog(true);
        CreatedPurchaseHeader."E-Document Link" := NullGuid;
        CreatedPurchaseHeader.Delete(true);
    end;

    [Test]
    internal procedure ReceiveFivePurchaseCreditMemos26()
    var
        EDocument: Record "E-Document";
        EDocService: Record "E-Document Service";
        EDocReceiveTest: Codeunit "E-Doc. Receive Test";
        EnvironmentInformation: Codeunit "Environment Information";
        EDocServicePage: TestPage "E-Document Service";
        i, j, LastEDocNo : Integer;
        Country: Text;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multiple e-documents in one file and create multiple purchase credit memos
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase credit memos
        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] purchase credit memo
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // Finding current last eDocument entry number
        EDocument.Reset();
        if EDocument.FindLast() then
            LastEDocNo := EDocument."Entry No";

        Country := EnvironmentInformation.GetApplicationFamily();
        if Country = 'ES' then
            BindSubscription(EDocReceiveTest);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        if Country = 'ES' then
            UnbindSubscription(EDocReceiveTest);

        // [THEN] 5 electronic documents are created
        EDocument.SetFilter("Entry No", '>%1', LastEDocNo);
        Assert.AreEqual(5, EDocument.Count(), '');
        // [THEN] Purchase credit memos are created with corresponfing values
        if EDocument.FindSet() then
            repeat
                CreatedPurchaseHeader.Reset();
                CreatedPurchaseHeader.SetRange("Document Type", CreatedPurchaseHeader."Document Type"::"Credit Memo");
                CreatedPurchaseHeader.SetRange("No.", EDocument."Document No.");
                CreatedPurchaseHeader.FindFirst();

                PurchaseHeader.Get(PurchaseHeader."Document Type"::"Credit Memo", CreatedPurchaseHeader."Vendor Invoice No.");

                CheckPurchaseHeadersAreEqual(PurchaseHeader, CreatedPurchaseHeader);

                CreatedPurchaseLine.SetRange("Document Type", CreatedPurchaseHeader."Document Type");
                CreatedPurchaseLine.SetRange("Document No.", CreatedPurchaseHeader."No.");
                if CreatedPurchaseLine.FindSet() then
                    repeat
                        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
                        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
                        PurchaseLine.SetRange("Line No.", CreatedPurchaseLine."Line No.");
                        PurchaseLine.FindFirst();
                        CheckPurchaseLinesAreEqual(PurchaseLine, CreatedPurchaseLine);
                    until CreatedPurchaseLine.Next() = 0;

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                CreatedPurchaseHeader.SetHideValidationDialog(true);
                CreatedPurchaseHeader."E-Document Link" := NullGuid;
                CreatedPurchaseHeader.Delete(true);
            until EDocument.Next() = 0;
    end;

    [Test]
    internal procedure ReceiveSinglePurchaseInvoiceToJournal26()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create journal line
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase invoice
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Debit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
        PurchaseHeader."Pay-to Name" := 'Journal Test Invoice';
        PurchaseHeader.Modify();

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal line is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        GenJnlLine.SetRange("Document No.", EDocumentPage."Document No.".Value());
        GenJnlLine.FindFirst();

        CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
        GenJnlLine.Delete(true);
        GenJnlBatch.Delete(true);
    end;

    [Test]
    internal procedure ReceiveMultiPurchaseInvoicesToJournal26()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        i, j : Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multiple e-documents and create multiple journal lines
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase invoices
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Debit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] purchase invoices
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");
            PurchaseHeader."Pay-to Name" := 'Journal Test Invoice no. ' + Format(i);
            PurchaseHeader.Modify();

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal lines are created with corresponfing values
        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        if GenJnlLine.FindSet() then
            repeat
                PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Invoice);
                PurchaseHeader.SetRange("Vendor Invoice No.", GenJnlLine."External Document No.");
                PurchaseHeader.FindFirst();

                CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                GenJnlLine.Delete(true);
            until GenJnlLine.Next() = 0;
    end;

    [Test]
    internal procedure ReceiveSinglePurchaseCreditMemoToJournal26()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and create journal line
        Initialize();

        // [GIVEN] e-Document service to receive one single purchase credit memo
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Credit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := false;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        // [GIVEN] purchase credit memo
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");
        PurchaseHeader."Pay-to Name" := 'Journal Test Invoice';
        PurchaseHeader.Modify();

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal line is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();

        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        GenJnlLine.SetRange("Document No.", EDocumentPage."Document No.".Value());
        GenJnlLine.FindFirst();

        CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
        GenJnlLine.Delete(true);
        GenJnlBatch.Delete(true);
    end;

    [Test]
    internal procedure ReceiveMultiCreditMemosToJournal26()
    var
        EDocService: Record "E-Document Service";
        GenJnlBatch: Record "Gen. Journal Batch";
        GenJnlLine: Record "Gen. Journal Line";
        PurchSetup: Record "Purchases & Payables Setup";
        EDocServicePage: TestPage "E-Document Service";
        i, j : Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive multiple e-documents and create multiple journal lines
        Initialize();

        // [GIVEN] e-Document service to receive multiple purchase credit memos
        LibraryJournals.CreateGenJournalBatch(GenJnlBatch);
        GenJnlBatch.Validate("No. Series", LibraryERM.CreateNoSeriesCode());
        GenJnlBatch.Validate("Bal. Account Type", GenJnlBatch."Bal. Account Type"::"G/L Account");
        GenJnlBatch.Modify(true);

        PurchSetup.Get();
        PurchSetup."Credit Acc. for Non-Item Lines" := LibraryERM.CreateGLAccountNoWithDirectPosting();
        PurchSetup.Modify(true);

        LibraryEDoc.CreateTestReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);

        EDocService."Lookup Account Mapping" := false;
        EDocService."Lookup Item GTIN" := false;
        EDocService."Lookup Item Reference" := false;
        EDocService."Resolve Unit Of Measure" := false;
        EDocService."Validate Line Discount" := false;
        EDocService."Verify Totals" := false;
        EDocService."Use Batch Processing" := true;
        EDocService."Create Journal Lines" := true;
        EDocService."General Journal Template Name" := GenJnlBatch."Journal Template Name";
        EDocService."General Journal Batch Name" := GenJnlBatch.Name;
        EDocService.Modify();

        PurchOrderTestBuffer.ClearTempVariables();

        // [GIVEN] purchase credit memos
        for i := 1 to 5 do begin
            LibraryPurchase.CreateVendorWithAddress(Vendor);
            Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
            Vendor.Modify();
            LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::"Credit Memo", Vendor."No.");
            PurchaseHeader."Pay-to Name" := 'Journal Test Invoice no. ' + Format(i);
            PurchaseHeader.Modify();

            for j := 1 to 3 do begin
                LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
                PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
                PurchaseLine.Modify(true);
            end;

            PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);
        end;

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase journal lines are created with corresponfing values
        GenJnlLine.SetRange("Journal Template Name", GenJnlBatch."Journal Template Name");
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch.Name);
        if GenJnlLine.FindSet() then
            repeat
                PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::"Credit Memo");
                PurchaseHeader.SetRange("Vendor Cr. Memo No.", GenJnlLine."External Document No.");
                PurchaseHeader.FindFirst();

                CheckGenJnlLineIsEqualToPurchaseHeader(PurchaseHeader, GenJnlLine);

                PurchaseHeader.SetHideValidationDialog(true);
                PurchaseHeader."E-Document Link" := NullGuid;
                PurchaseHeader.Delete(true);

                GenJnlLine.Delete(true);
            until GenJnlLine.Next() = 0;
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler')]
    internal procedure GetBasicInfoFromReceivedDocumentError26()
    var
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and try to get besic info
        Initialize();

        // [GIVEN] e-Document service to raised receiving error
        LibraryEDoc.CreateGetBasicInfoErrorReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowBasicInfoError();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();
        Assert.AreEqual(GetBasicInfoErr, EDocumentPage.ErrorMessagesPart.Description.Value(), '');

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
    end;

    [Test]
    [HandlerFunctions('ConfirmHandler')]
    internal procedure GetCompleteInfoFromReceivedDocumentError26()
    var
        EDocService: Record "E-Document Service";
        EDocServicePage: TestPage "E-Document Service";
        EDocumentPage: TestPage "E-Document";
        i: Integer;
    begin
        // [FEATURE] [E-Document] [Receive]
        // [SCENARIO] Receive single e-document and try to get besic info
        Initialize();

        // [GIVEN] e-Document service to raised receiving error
        LibraryEDoc.CreateGetCompleteInfoErrorReceiveServiceForEDoc(EDocService, Enum::"E-Document Integration"::Mock);
        BindSubscription(EDocImplState);
        EDocImplState.SetThrowCompleteInfoError();

        // [GIVEN] purchase invoice
        LibraryPurchase.CreateVendorWithAddress(Vendor);
        Vendor."Receive E-Document To" := Vendor."Receive E-Document To"::"Purchase Invoice";
        Vendor.Modify();
        LibraryPurchase.CreatePurchHeader(PurchaseHeader, PurchaseHeader."Document Type"::Invoice, Vendor."No.");

        for i := 1 to 3 do begin
            LibraryPurchase.CreatePurchaseLine(PurchaseLine, PurchaseHeader, PurchaseLine.Type::Item, LibraryInventory.CreateItemNo(), LibraryRandom.RandInt(100));
            PurchaseLine.Validate("Direct Unit Cost", LibraryRandom.RandDecInRange(1, 100, 2));
            PurchaseLine.Modify(true);
        end;

        PurchOrderTestBuffer.ClearTempVariables();
        PurchOrderTestBuffer.AddPurchaseDocToTemp(PurchaseHeader);

        // [WHEN] Running Receive
        EDocServicePage.OpenView();
        EDocServicePage.Filter.SetFilter(Code, EDocService.Code);
        EDocServicePage.Receive.Invoke();

        // [THEN] Purchase invoice is created with corresponfing values
        EDocumentPage.OpenView();
        EDocumentPage.Last();
        Assert.AreEqual(GetCompleteInfoErr, EDocumentPage.ErrorMessagesPart.Description.Value(), '');

        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader."E-Document Link" := NullGuid;
        PurchaseHeader.Delete(true);
    end;
#pragma warning restore AL0432
#endif
}
