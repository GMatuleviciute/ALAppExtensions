// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.EServices.EDocument;

using Microsoft.Purchases.History;
using System.IO;
using System.Utilities;

codeunit 5588 "Voucher E-Document Check" implements "Digital Voucher Check"
{
    Access = Internal;

    internal procedure CheckVoucherIsAttachedToDocument(var ErrorMessageMgt: Codeunit "Error Message Management"; DigitalVoucherEntryType: Enum "Digital Voucher Entry Type"; RecRef: RecordRef)
    var
        EDocument: Record "E-Document";
        EDocumentLinkGuid: Guid;
        NotPossibleToPostWithoutEDocumentErr: Label 'Not possible to post without linking an E-Document.';
    begin
        if DigitalVoucherEntryType = DigitalVoucherEntryType::"Sales Document" then
            exit;

        if DigitalVoucherEntryType <> DigitalVoucherEntryType::"Purchase Document" then
            exit;

        EDocumentLinkGuid := GetEDocumentLinkFromPurchaseHeader(RecRef);

        if IsNullGuid(EDocumentLinkGuid) then begin
            ErrorMessageMgt.LogSimpleErrorMessage(NotPossibleToPostWithoutEDocumentErr);
            exit;
        end;

        EDocument.SetRange(SystemId, EDocumentLinkGuid);
        if EDocument.FindFirst() then
            exit;

        ErrorMessageMgt.LogSimpleErrorMessage(NotPossibleToPostWithoutEDocumentErr);
    end;

    internal procedure GenerateDigitalVoucherForPostedDocument(DigitalVoucherEntryType: Enum "Digital Voucher Entry Type"; RecRef: RecordRef)
    var
        DigitalVoucherEntrySetup: Record "Digital Voucher Entry Setup";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr.";
        EDocument: Record "E-Document";
        DigitalVoucherImpl: Codeunit "Digital Voucher Impl.";
        DigitalVoucherCheck: Interface "Digital Voucher Check";
    begin
        DigitalVoucherImpl.GetDigitalVoucherEntrySetup(DigitalVoucherEntrySetup, DigitalVoucherEntryType);
        DigitalVoucherCheck := DigitalVoucherEntrySetup."Check Type"::Attachment;
        DigitalVoucherCheck.GenerateDigitalVoucherForPostedDocument(DigitalVoucherEntrySetup."Entry Type", RecRef);
    end;

    local procedure GetEDocumentLinkFromPurchaseHeader(RecRef: RecordRef): Guid
    var
        EDocumentLinkFieldRef: FieldRef;
        NullGuid: Guid;
        FieldIndex: Integer;
    begin
        for FieldIndex := 1 to RecRef.FieldCount do begin
            EDocumentLinkFieldRef := RecRef.FieldIndex(FieldIndex);
            if EDocumentLinkFieldRef.Name = 'E-Document Link' then
                exit(EDocumentLinkFieldRef.Value());
        end;
        exit(NullGuid);
    end;

    /// <summary>
    /// Attaches the original E-Document file to the Incoming Document of a Purchase Header.
    /// Creates an Incoming Document Attachment and links it to the Purchase Header.
    /// </summary>
    /// <param name="EDocument">The E-Document containing the file to attach</param>
    /// <param name="DocumentNo">The document number to attach the incoming document to</param>
    /// <param name="PostingDate">The posting date of the document</param>
    internal procedure AttachToIncomingDocument(EDocument: Record "E-Document"; DocumentNo: Code[20]; PostingDate: Date)
    var
        EDocDataStorage: Record "E-Doc. Data Storage";
        IncomingDocumentAttachment: Record "Incoming Document Attachment";
        EDocumentService: Record "E-Document Service";
        ImportAttachmentIncDoc: Codeunit "Import Attachment - Inc. Doc.";
        TempBlob: Codeunit "Temp Blob";
        FileName: Text;
        EDocumentFileNameLbl: Label 'E-Document_%1.%2', Comment = '%1 = E-Document Entry No., %2 = File Format', Locked = true;
    begin
        if not (EDocument."Document Type" in [
            EDocument."Document Type"::"Purchase Invoice",
            EDocument."Document Type"::"Purchase Credit Memo",
            EDocument."Document Type"::"Purchase Order",
            EDocument."Document Type"::"Purchase Quote",
            EDocument."Document Type"::"Purchase Return Order"]) then
            exit;

        EDocumentService.Get(EDocument.Service);
        if EDocument."Unstructured Data Entry No." = 0 then
            exit;

        if not EDocDataStorage.Get(EDocument."Unstructured Data Entry No.") then
            exit;

        TempBlob := EDocDataStorage.GetTempBlob();
        if not TempBlob.HasValue() then
            exit;

        if EDocument."File Name" <> '' then
            FileName := EDocument."File Name"
        else
            FileName := StrSubstNo(EDocumentFileNameLbl, EDocument."Entry No", EDocDataStorage."File Format");

        IncomingDocumentAttachment.SetRange("Document No.", DocumentNo);
        IncomingDocumentAttachment.SetRange("Posting Date", PostingDate);
        IncomingDocumentAttachment.SetContentFromBlob(TempBlob);

        if not ImportAttachmentIncDoc.ImportAttachment(IncomingDocumentAttachment, FileName, TempBlob) then
            exit;

        IncomingDocumentAttachment."Is E-Document" := true;
        IncomingDocumentAttachment.Modify(false);

        if EDocDataStorage."File Format" = EDocDataStorage."File Format"::PDF then begin
            FileName := StrSubstNo(EDocumentFileNameLbl, EDocument."Entry No", EDocDataStorage."File Format"::XML);
            ExtractXMLFromPDF(TempBlob, FileName, IncomingDocumentAttachment);
        end;
    end;

    local procedure ExtractXMLFromPDF(var TempBlob: Codeunit System.Utilities."Temp Blob"; FileName: Text; var IncomingDocumentAttachment: Record "Incoming Document Attachment")
    var
        PDFDocument: Codeunit "PDF Document";
        ImportAttachmentIncDoc: Codeunit "Import Attachment - Inc. Doc.";
        ExtractedXmlBlob: Codeunit "Temp Blob";
        PdfInStream: InStream;
    begin
        TempBlob.CreateInStream(PdfInStream);
        if not PDFDocument.GetDocumentAttachmentStream(PdfInStream, ExtractedXmlBlob) then
            exit;

        if not ExtractedXmlBlob.HasValue() then
            exit;

        IncomingDocumentAttachment.Default := false;
        IncomingDocumentAttachment."Main Attachment" := false;
        if not ImportAttachmentIncDoc.ImportAttachment(IncomingDocumentAttachment, FileName, ExtractedXmlBlob) then
            exit;

        IncomingDocumentAttachment."Is E-Document" := true;
        IncomingDocumentAttachment.Modify(false);
    end;
}
