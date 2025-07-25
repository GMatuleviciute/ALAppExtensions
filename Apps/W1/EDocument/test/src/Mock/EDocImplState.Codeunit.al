codeunit 139630 "E-Doc. Impl. State"
{
    EventSubscriberInstance = Manual;

    var
        TempPurchHeader: Record "Purchase Header" temporary;
        TempPurchLine: Record "Purchase Line" temporary;
        PurchDocTestBuffer: Codeunit "E-Doc. Test Buffer";
        LibraryVariableStorage: Codeunit "Library - Variable Storage";
        EnableOnCheck, DisableOnCreateOutput, DisableOnCreateBatch, IsAsync2, EnableHttpData, ThrowIntegrationRuntimeError, ThrowIntegrationLoggedError : Boolean;
        ThrowRuntimeError, ThrowLoggedError, ThrowBasicInfoError, ThrowCompleteInfoError, OnGetResponseSuccess, OnGetApprovalSuccess, ActionHasUpdate : Boolean;
        LocalHttpResponse: HttpResponseMessage;
        ActionStatus: Enum "E-Document Service Status";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Export", 'OnAfterCreateEDocument', '', false, false)]
    local procedure OnAfterCreateEDocument(var EDocument: Record "E-Document")
    begin
        LibraryVariableStorage.Enqueue(EDocument);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Export", 'OnBeforeCreateEDocument', '', false, false)]
    local procedure OnBeforeCreatedEDocument(var EDocument: Record "E-Document")
    begin
        LibraryVariableStorage.Enqueue(EDocument);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnCheck', '', false, false)]
    local procedure OnCheck(var SourceDocumentHeader: RecordRef; EDocService: Record "E-Document Service"; EDocumentProcessingPhase: enum "E-Document Processing Phase")
    var
        ErrorMessageMgt: Codeunit "Error Message Management";
    begin
        if not EnableOnCheck then
            exit;
        if ThrowRuntimeError then
            Error('TEST');
        if ThrowLoggedError then
            ErrorMessageMgt.LogErrorMessage(4, 'TEST', EDocService, EDocService.FieldNo("Auto Import"), '');

        LibraryVariableStorage.Enqueue(SourceDocumentHeader);
        LibraryVariableStorage.Enqueue(EDocService);
        LibraryVariableStorage.Enqueue(EDocumentProcessingPhase.AsInteger());
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnCreate', '', false, false)]
    local procedure OnCreate(EDocService: Record "E-Document Service"; var EDocument: Record "E-Document"; var SourceDocumentHeader: RecordRef; var SourceDocumentLines: RecordRef; var TempBlob: codeunit "Temp Blob")
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
        OutStream: OutStream;
    begin
        if ThrowRuntimeError then
            Error('TEST');
        if ThrowLoggedError then
            EDocErrorHelper.LogErrorMessage(EDocument, EDocService, EDocService.FieldNo("Auto Import"), 'TEST');

        if not DisableOnCreateOutput then begin
            TempBlob.CreateOutStream(OutStream);
            OutStream.WriteText('TEST');
            LibraryVariableStorage.Enqueue(TempBlob.Length());
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnCreateBatch', '', false, false)]
    local procedure OnCreateBatch(EDocService: Record "E-Document Service"; var EDocuments: Record "E-Document"; var SourceDocumentHeaders: RecordRef; var SourceDocumentsLines: RecordRef; var TempBlob: codeunit "Temp Blob")
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
        OutStream: OutStream;
    begin
        if ThrowRuntimeError then
            Error('TEST');
        if ThrowLoggedError then
            EDocErrorHelper.LogErrorMessage(EDocuments, EDocService, EDocService.FieldNo("Auto Import"), 'TEST');

        if not DisableOnCreateBatch then begin
            TempBlob.CreateOutStream(OutStream);
            OutStream.WriteText('TEST');
            LibraryVariableStorage.Enqueue(TempBlob.Length());
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnGetBasicInfoFromReceivedDocument', '', false, false)]
    local procedure OnGetBasicInfoFromReceivedDocument(var EDocument: Record "E-Document"; var TempBlob: codeunit "Temp Blob")
    var
        CompanyInformation: Record "Company Information";
        GLSetup: Record "General Ledger Setup";
    begin
        if ThrowBasicInfoError then
            Error('Test Get Basic Info From Received Document Error.');

        CompanyInformation.Get();
        GLSetup.Get();

        PurchDocTestBuffer.GetPurchaseDocToTempVariables(TempPurchHeader, TempPurchLine);
        if TempPurchHeader.FindFirst() then begin
            if EDocument."Index In Batch" <> 0 then
                TempPurchHeader.Next(EDocument."Index In Batch" - 1);

            case TempPurchHeader."Document Type" of
                TempPurchHeader."Document Type"::Invoice:
                    begin
                        EDocument."Document Type" := EDocument."Document Type"::"Purchase Invoice";
                        EDocument."Incoming E-Document No." := TempPurchHeader."Vendor Invoice No.";
                    end;
                TempPurchHeader."Document Type"::"Credit Memo":
                    begin
                        EDocument."Document Type" := EDocument."Document Type"::"Purchase Credit Memo";
                        EDocument."Incoming E-Document No." := TempPurchHeader."Vendor Cr. Memo No.";
                    end;
            end;

            EDocument."Bill-to/Pay-to No." := TempPurchHeader."Pay-to Vendor No.";
            EDocument."Bill-to/Pay-to Name" := TempPurchHeader."Pay-to Name";
            EDocument."Document Date" := TempPurchHeader."Document Date";
            EDocument."Due Date" := TempPurchHeader."Due Date";
            EDocument."Receiving Company VAT Reg. No." := CompanyInformation."VAT Registration No.";
            EDocument."Receiving Company GLN" := CompanyInformation.GLN;
            EDocument."Receiving Company Name" := CompanyInformation.Name;
            EDocument."Receiving Company Address" := CompanyInformation.Address;
            EDocument."Currency Code" := GLSetup."LCY Code";
            TempPurchHeader.CalcFields(Amount, "Amount Including VAT");
            EDocument."Amount Excl. VAT" := TempPurchHeader.Amount;
            EDocument."Amount Incl. VAT" := TempPurchHeader."Amount Including VAT";
            EDocument."Order No." := PurchDocTestBuffer.GetEDocOrderNo();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Format Mock", 'OnGetCompleteInfoFromReceivedDocument', '', false, false)]
    local procedure OnGetCompleteInfoFromReceivedDocument(var EDocument: Record "E-Document"; var CreatedDocumentHeader: RecordRef; var CreatedDocumentLines: RecordRef; var TempBlob: codeunit "Temp Blob")
    var
        TempPurchHeader2: Record "Purchase Header" temporary;
        TempPurchLine2: Record "Purchase Line" temporary;
    begin
        if ThrowCompleteInfoError then
            Error('Test Get Complete Info From Received Document Error.');

        PurchDocTestBuffer.GetPurchaseDocToTempVariables(TempPurchHeader, TempPurchLine);
        if TempPurchHeader.FindFirst() then begin
            if EDocument."Index In Batch" <> 0 then
                TempPurchHeader.Next(EDocument."Index In Batch" - 1);

            TempPurchHeader2.Init();
            TempPurchHeader2.TransferFields(TempPurchHeader);
            TempPurchHeader2."Vendor Invoice No." := TempPurchHeader."No.";
            TempPurchHeader2.Insert();

            TempPurchLine.SetRange("Document Type", TempPurchHeader."Document Type");
            TempPurchLine.SetRange("Document No.", TempPurchHeader."No.");
            if TempPurchLine.FindSet() then
                repeat
                    TempPurchLine2.Init();
                    TempPurchLine2.TransferFields(TempPurchLine);
                    TempPurchLine2.Insert();
                until TempPurchLine.Next() = 0;
        end;

        CreatedDocumentHeader.GetTable(TempPurchHeader2);
        CreatedDocumentLines.GetTable(TempPurchLine2);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock V2", OnSend, '', false, false)]
    local procedure OnSendV2(var EDocument: Record "E-Document"; var TempBlob: Codeunit "Temp Blob"; var IsAsync: Boolean; HttpRequest: HttpRequestMessage; HttpResponse: HttpResponseMessage)
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        IsAsync := IsAsync2;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');

        if EnableHttpData then begin
            HttpRequest.SetRequestUri('http://cronus.test');
            HttpRequest.Method := 'POST';

            HttpRequest.Content.WriteFrom('Test request');
            HttpResponse.Content.WriteFrom('Test response');
            HttpResponse.Headers.Add('Accept', '*');
        end;

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Int Mock No Async", OnSend, '', false, false)]
    local procedure OnSendV2NoAsync(var EDocument: Record "E-Document"; var TempBlob: Codeunit "Temp Blob"; var IsAsync: Boolean; HttpRequest: HttpRequestMessage; HttpResponse: HttpResponseMessage)
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        IsAsync := IsAsync2;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');

        if EnableHttpData then begin
            HttpRequest.SetRequestUri('http://cronus.test');
            HttpRequest.Method := 'POST';

            HttpRequest.Content.WriteFrom('Test request');
            HttpResponse.Content.WriteFrom('Test response');
            HttpResponse.Headers.Add('Accept', '*');
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock V2", OnGetResponse, '', false, false)]
    local procedure OnGetResponseV2(var EDocument: Record "E-Document"; HttpRequest: HttpRequestMessage; HttpResponse: HttpResponseMessage; var Success: Boolean)
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        Success := OnGetResponseSuccess;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');

        if EnableHttpData then begin
            HttpRequest.SetRequestUri('http://cronus.test');
            HttpRequest.Method := 'POST';

            HttpRequest.Content.WriteFrom('Test request');
            HttpResponse.Content.WriteFrom('Test response');
            HttpResponse.Headers.Add('Accept', '*');
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock V2", OnReceiveDocuments, '', false, false)]
    local procedure OnReceiveDocuments(ReceivedEDocuments: codeunit "Temp Blob List"; HttpRequestMessage: HttpRequestMessage; HttpResponseMessage: HttpResponseMessage)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        I, C : Integer;
    begin
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        if LibraryVariableStorage.Length() > 0 then
            OutStr.WriteText(LibraryVariableStorage.DequeueText())
        else
            OutStr.WriteText('Some Test Content');

        if LibraryVariableStorage.Length() > 0 then begin
            C := LibraryVariableStorage.DequeueInteger();
            for I := 1 to C do
                ReceivedEDocuments.Add(TempBlob)
        end else begin
            PurchDocTestBuffer.GetPurchaseDocToTempVariables(TempPurchHeader, TempPurchLine);
            if TempPurchHeader.Count() > 0 then
                for I := 1 to TempPurchHeader.Count() do
                    ReceivedEDocuments.Add(TempBlob);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock V2", OnDownloadDocument, '', false, false)]
    local procedure OnDownloadDocument(var EDocument: Record "E-Document"; var EDocumentService: Record "E-Document Service"; DocumentMetadata: Codeunit "Temp Blob"; var DocumentDownloadBlob: Codeunit "Temp Blob"; HttpRequest: HttpRequestMessage; HttpResponse: HttpResponseMessage)
    begin
        DocumentDownloadBlob := DocumentMetadata;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock V2", OnGetApproval, '', false, false)]
    local procedure OnGetApprovalV2(var EDocument: Record "E-Document"; var EDocumentService: Record "E-Document Service"; HttpRequest: HttpRequestMessage; HttpResponse: HttpResponseMessage; var Status: Enum "E-Document Service Status"; var Update: Boolean);
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        Status := ActionStatus;
        Update := ActionHasUpdate;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock V2", OnGetCancellation, '', false, false)]
    local procedure OnOnGetCancellationV2(var EDocument: Record "E-Document"; var EDocumentService: Record "E-Document Service"; HttpRequest: HttpRequestMessage; HttpResponse: HttpResponseMessage; var Status: Enum "E-Document Service Status"; var Update: Boolean);
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        Status := ActionStatus;
        Update := ActionHasUpdate;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');
    end;


#if not CLEAN26
#pragma warning disable AL0432
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock", 'OnSend', '', false, false)]
    local procedure OnSend(var EDocument: Record "E-Document"; var TempBlob: Codeunit "Temp Blob"; var IsAsync: Boolean; var HttpRequest: HttpRequestMessage; var HttpResponse: HttpResponseMessage)
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        IsAsync := IsAsync2;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');

        if EnableHttpData then begin
            HttpRequest.SetRequestUri('http://cronus.test');
            HttpRequest.Method := 'POST';

            HttpRequest.Content.WriteFrom('Test request');
            HttpResponse.Content.WriteFrom('Test response');
            HttpResponse.Headers.Add('Accept', '*');
        end;

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock", 'OnGetResponse', '', false, false)]
    local procedure OnGetResponse(var EDocument: Record "E-Document"; var HttpRequest: HttpRequestMessage; var HttpResponse: HttpResponseMessage; var Success: Boolean)
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        Success := OnGetResponseSuccess;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');

        if EnableHttpData then begin
            HttpRequest.SetRequestUri('http://cronus.test');
            HttpRequest.Method := 'POST';

            HttpRequest.Content.WriteFrom('Test request');
            HttpResponse.Content.WriteFrom('Test response');
            HttpResponse.Headers.Add('Accept', '*');
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock", 'OnGetDocumentCountInBatch', '', false, false)]
    local procedure OnGetDocumentCountInBatch(var Count: Integer)
    var
        TempPurchHeader2: Record "Purchase Header" temporary;
        TempPurchLine2: Record "Purchase Line" temporary;
        PurchDocTestBuffer2: Codeunit "E-Doc. Test Buffer";
    begin
        if LibraryVariableStorage.Length() > 0 then
            Count := LibraryVariableStorage.DequeueInteger()
        else begin
            PurchDocTestBuffer2.GetPurchaseDocToTempVariables(TempPurchHeader2, TempPurchLine2);
            Count := TempPurchHeader2.Count();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock", 'OnReceiveDocument', '', false, false)]
    local procedure OnReceiveDocument(var TempBlob: codeunit "Temp Blob"; var HttpRequest: HttpRequestMessage; var HttpResponse: HttpResponseMessage)
    var
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr, TextEncoding::UTF8);
        if LibraryVariableStorage.Length() > 0 then
            OutStr.WriteText(LibraryVariableStorage.DequeueText())
        else
            OutStr.WriteText('Some Test Content');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"E-Doc. Integration Mock", 'OnGetApproval', '', false, false)]
    local procedure OnGetApproval(var EDocument: Record "E-Document"; var HttpRequest: HttpRequestMessage; var HttpResponse: HttpResponseMessage; var Success: Boolean)
    var
        EDocErrorHelper: Codeunit "E-Document Error Helper";
    begin
        Success := OnGetApprovalSuccess;
        HttpResponse := LocalHttpResponse;

        if ThrowIntegrationRuntimeError then
            Error('TEST');

        if ThrowIntegrationLoggedError then
            EDocErrorHelper.LogSimpleErrorMessage(EDocument, 'TEST');
    end;
#pragma warning restore AL0432
#endif

#if not CLEAN26
    internal procedure SetOnGetApprovalSuccess()
    begin
        OnGetApprovalSuccess := true;
    end;
#endif

    internal procedure SetActionReturnStatus(Value: Enum "E-Document Service Status")
    begin
        ActionStatus := Value;
    end;

    internal procedure SetActionHasUpdate(Value: Boolean)
    begin
        ActionHasUpdate := Value;
    end;

    internal procedure SetOnGetResponseSuccess()
    begin
        OnGetResponseSuccess := true;
    end;

    internal procedure SetThrowCompleteInfoError()
    begin
        ThrowCompleteInfoError := true;
    end;

    internal procedure SetThrowBasicInfoError()
    begin
        ThrowBasicInfoError := true;
    end;

    internal procedure SetDisableOnCreateOutput()
    begin
        DisableOnCreateOutput := true;
    end;

    internal procedure SetDisableOnCreateBatchOutput()
    begin
        DisableOnCreateBatch := true;
    end;

    internal procedure EnableOnCheckEvent()
    begin
        EnableOnCheck := true;
    end;

    internal procedure SetThrowRuntimeError()
    begin
        ThrowRuntimeError := true;
    end;

    internal procedure SetThrowLoggedError()
    begin
        ThrowLoggedError := true;
    end;

    internal procedure SetIsAsync()
    begin
        IsAsync2 := true;
    end;

    internal procedure SetEnableHttpData()
    begin
        EnableHttpData := true;
    end;

    internal procedure SetThrowIntegrationLoggedError()
    begin
        ThrowIntegrationLoggedError := true;
    end;

    internal procedure SetThrowIntegrationRuntimeError()
    begin
        ThrowIntegrationRuntimeError := true;
    end;

    internal procedure SetHttpResponse(HttpResponse: HttpResponseMessage)
    begin
        LocalHttpResponse := HttpResponse;
    end;

    internal procedure SetVariableStorage(var NewLibraryVariableStorage: Codeunit "Library - Variable Storage")
    begin
        LibraryVariableStorage := NewLibraryVariableStorage;
    end;

    internal procedure GetVariableStorage(var NewLibraryVariableStorage: Codeunit "Library - Variable Storage")
    begin
        NewLibraryVariableStorage := LibraryVariableStorage;
    end;


}