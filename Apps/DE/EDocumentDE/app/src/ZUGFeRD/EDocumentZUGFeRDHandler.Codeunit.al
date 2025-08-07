// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument.Formats;

using Microsoft.eServices.EDocument;
using Microsoft.eServices.EDocument.Helpers;
using Microsoft.eServices.EDocument.Processing.Import;
using Microsoft.eServices.EDocument.Processing.Import.Purchase;
using Microsoft.eServices.EDocument.Processing.Interfaces;
using Microsoft.eServices.EDocument.Service.Participant;
using Microsoft.Purchases.Vendor;
using System.IO;
using System.Telemetry;
using System.Utilities;

/// <summary>
/// Handler for processing ZUGFeRD electronic documents.
/// Implements structured format reader interface for importing ZUGFeRD invoices and credit memos.
/// </summary>
codeunit 11036 "E-Document ZUGFeRD Handler" implements IStructuredFormatReader
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
        FeatureNameTok: Label 'E-document ZUGFeRD Format', Locked = true;
        StartEventNameTok: Label 'E-document ZUGFeRD import started. Parsing basic information.', Locked = true;
        ContinueEventNameTok: Label 'Parsing complete information for E-document ZUGFeRD import.', Locked = true;
        EndEventNameTok: Label 'E-document ZUGFeRD import completed. %1 #%2 created.', Locked = true;

    /// <summary>
    /// Reads a ZUGFeRD electronic document into a draft purchase document.
    /// Extracts XML from PDF and populates purchase header and lines based on document type (Invoice or Credit Note).
    /// </summary>
    /// <param name="EDocument">The E-Document record to process.</param>
    /// <param name="TempBlob">The temporary blob containing the PDF content to parse.</param>
    /// <returns>Returns the process draft type indicating a Purchase Document was created.</returns>
    internal procedure ReadIntoDraft(EDocument: Record "E-Document"; TempBlob: Codeunit "Temp Blob"): Enum "E-Doc. Process Draft"
    var
        EDocumentPurchaseHeader: Record "E-Document Purchase Header";
        PDFDocument: Codeunit "PDF Document";
        TempXMLBlob: Codeunit "Temp Blob";
        EDocumentXMLHelper: Codeunit "EDocument XML Helper";
        EDocumentType: Enum "E-Document Type";
        ZUGFeRDXml: XmlDocument;
        XmlNamespaces: XmlNamespaceManager;
        XmlElement: XmlElement;
        NoXMLFileErr: Label 'No invoice attachment found in the PDF file. Please check the PDF file.';
        InvalidZUGFeRDFormatErr: Label 'Invalid ZUGFeRD format. Expected CrossIndustryInvoice root element but found: %1', Comment = '%1 = Actual root element name';
        UnsupportedDocumentTypeErr: Label 'Unsupported document type: %1', Comment = '%1 = Document type';
        CrossIndustryInvoiceTok: Label 'CrossIndustryInvoice', Locked = true;
        DocumentTypeCode: Text;
    begin
        FeatureTelemetry.LogUsage('0000ESH', FeatureNameTok, StartEventNameTok);
        EDocumentPurchaseHeader.InsertForEDocument(EDocument);

        if not PDFDocument.GetDocumentAttachmentStream(TempBlob.CreateInStream(), TempXMLBlob) then
            Error(NoXMLFileErr);

        if not XmlDocument.ReadFrom(TempBlob.CreateInStream(TextEncoding::UTF8), ZUGFeRDXml) then
            Error(NoXMLFileErr);

        if not ZUGFeRDXml.GetRoot(XmlElement) then
            Error(NoXMLFileErr);

        if XmlElement.LocalName() <> CrossIndustryInvoiceTok then
            Error(InvalidZUGFeRDFormatErr, XmlElement.LocalName());

        FeatureTelemetry.LogUsage('0000EXS', FeatureNameTok, ContinueEventNameTok);

        XmlNamespaces.AddNamespace('rsm', 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100');
        XmlNamespaces.AddNamespace('ram', 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100');
        XmlNamespaces.AddNamespace('udt', 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100');
        XmlNamespaces.AddNamespace('qdt', 'urn:un:unece:uncefact:data:standard:QualifiedDataType:100');

        DocumentTypeCode := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:TypeCode');
        if DocumentTypeCode = '' then
            Error(UnsupportedDocumentTypeErr, '');

        if not IsDocumentTypeSupported(DocumentTypeCode, EDocumentType) then begin
            FeatureTelemetry.LogUsage('0000EXE', FeatureNameTok, StrSubstNo(UnsupportedDocumentTypeErr, DocumentTypeCode));
            Error(UnsupportedDocumentTypeErr, DocumentTypeCode);
        end;

        PopulateEDocumentHeader(ZUGFeRDXml, XmlNamespaces, EDocumentPurchaseHeader, EDocumentType);
        InsertZUGFeRDPurchaseLines(ZUGFeRDXml, XmlNamespaces, EDocument."Entry No");

        EDocumentPurchaseHeader.Modify(false);
        EDocument.Direction := EDocument.Direction::Incoming;

        FeatureTelemetry.LogUsage('0000WXJ', FeatureNameTok, StrSubstNo(EndEventNameTok, EDocument."Document Type", EDocument."Incoming E-Document No."));
        exit(Enum::"E-Doc. Process Draft"::"Purchase Document");
    end;

    /// <summary>
    /// Opens a page to view the readable purchase document content for the specified E-Document.
    /// Displays purchase header and line information in a user-friendly format.
    /// </summary>
    /// <param name="EDocument">The E-Document record to view.</param>
    /// <param name="TempBlob">The temporary blob containing the document content (not used in current implementation).</param>
    internal procedure View(EDocument: Record "E-Document"; TempBlob: Codeunit "Temp Blob")
    var
        EDocPurchaseHeader: Record "E-Document Purchase Header";
        EDocPurchaseLine: Record "E-Document Purchase Line";
        EDocReadablePurchaseDoc: Page "E-Doc. Readable Purchase Doc.";
    begin
        EDocPurchaseHeader.GetFromEDocument(EDocument);
        EDocPurchaseLine.SetRange("E-Document Entry No.", EDocPurchaseHeader."E-Document Entry No.");
        EDocReadablePurchaseDoc.SetBuffer(EDocPurchaseHeader, EDocPurchaseLine);
        EDocReadablePurchaseDoc.Run();
    end;

    local procedure PopulateEDocumentHeader(ZUGFeRDXml: XmlDocument; XmlNamespaces: XmlNamespaceManager; var EDocumentPurchaseHeader: Record "E-Document Purchase Header"; DocumentType: Enum "E-Document Type")
    var
        EDocumentXMLHelper: Codeunit "EDocument XML Helper";
        DocumentID: Text;
        IssueDateString: Text;
        CurrencyCode: Text;
        TotalAmountString: Text;
        TaxAmountString: Text;
        NetAmountString: Text;
        IssueDate: Date;
        TotalAmount: Decimal;
        TaxAmount: Decimal;
        NetAmount: Decimal;
    begin
        EDocumentPurchaseHeader."E-Document Type" := DocumentType;
        DocumentID := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID');
        EDocumentPurchaseHeader."Sales Invoice No." := CopyStr(DocumentID, 1, MaxStrLen(EDocumentPurchaseHeader."Sales Invoice No."));
        IssueDateString := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:IssueDateTime/udt:DateTimeString');
        IssueDate := EvaluateZUGFeRDDate(IssueDateString);
        if IssueDate <> 0D then
            EDocumentPurchaseHeader."Document Date" := IssueDate;
        CurrencyCode := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode');
        EDocumentPurchaseHeader."Currency Code" := CopyStr(CurrencyCode, 1, MaxStrLen(EDocumentPurchaseHeader."Currency Code"));
        TotalAmountString := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:GrandTotalAmount');
        if Evaluate(TotalAmount, TotalAmountString) then
            EDocumentPurchaseHeader.Total := TotalAmount;
        TaxAmountString := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:TaxTotalAmount');
        if Evaluate(TaxAmount, TaxAmountString) then
            EDocumentPurchaseHeader."Total VAT" := TaxAmount;
        NetAmountString := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation/ram:LineTotalAmount');
        if Evaluate(NetAmount, NetAmountString) then
            EDocumentPurchaseHeader."Sub Total" := NetAmount;
        ParseAccountingSupplierParty(ZUGFeRDXml, XmlNamespaces, EDocumentPurchaseHeader);
        ParseAccountingCustomerParty(ZUGFeRDXml, XmlNamespaces, EDocumentPurchaseHeader);
    end;

    local procedure ParseAccountingSupplierParty(ZUGFeRDXml: XmlDocument; XmlNamespaces: XmlNamespaceManager; var EDocumentPurchaseHeader: Record "E-Document Purchase Header")
    var
        EDocumentXMLHelper: Codeunit "EDocument XML Helper";
        EDocumentImportHelper: Codeunit "E-Document Import Helper";
        VendorName: Text;
        VendorAddress: Text;
        VATRegistrationNo: Text[20];
        GLN: Code[13];
        VendorNo: Code[20];
    begin
        VendorName := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:Name');
        EDocumentPurchaseHeader."Vendor Company Name" := CopyStr(VendorName, 1, MaxStrLen(EDocumentPurchaseHeader."Vendor Company Name"));
        VATRegistrationNo := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID="VA"]'), 1, MaxStrLen(VATRegistrationNo));
        EDocumentPurchaseHeader."Vendor VAT Id" := VATRegistrationNo;
        GLN := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:GlobalID[@schemeID="0088"]'), 1, MaxStrLen(GLN));
        if GLN = '' then
            GLN := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:SpecifiedLegalOrganization/ram:ID[@schemeID="0002"]'), 1, MaxStrLen(GLN));
        EDocumentPurchaseHeader."Vendor GLN" := GLN;
        VendorAddress := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:PostalTradeAddress/ram:LineOne');
        EDocumentPurchaseHeader."Vendor Address" := CopyStr(VendorAddress, 1, MaxStrLen(EDocumentPurchaseHeader."Vendor Address"));
        EDocumentPurchaseHeader."Vendor Address Recipient" := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:SellerTradeParty/ram:DefinedTradeContact/ram:PersonName'), 1, MaxStrLen(EDocumentPurchaseHeader."Vendor Address Recipient"));
        VendorNo := EDocumentImportHelper.FindVendor('', GLN, VATRegistrationNo);
        if VendorNo = '' then
            VendorNo := EDocumentImportHelper.FindVendorByNameAndAddress(VendorName, VendorAddress);
    end;

    local procedure ParseAccountingCustomerParty(ZUGFeRDXml: XmlDocument; XmlNamespaces: XmlNamespaceManager; var EDocumentPurchaseHeader: Record "E-Document Purchase Header")
    var
        EDocumentXMLHelper: Codeunit "EDocument XML Helper";
        CustomerName: Text;
        CustomerAddress: Text;
        VATRegistrationNo: Text[100];
        GLN: Code[13];
    begin
        CustomerName := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:Name');
        EDocumentPurchaseHeader."Customer Company Name" := CopyStr(CustomerName, 1, MaxStrLen(EDocumentPurchaseHeader."Customer Company Name"));
        VATRegistrationNo := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID="VA"]'), 1, MaxStrLen(VATRegistrationNo));
        EDocumentPurchaseHeader."Customer VAT Id" := CopyStr(VATRegistrationNo, 1, MaxStrLen(EDocumentPurchaseHeader."Customer VAT Id"));
        GLN := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:GlobalID[@schemeID="0088"]'), 1, MaxStrLen(GLN));
        if GLN = '' then
            GLN := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:SpecifiedLegalOrganization/ram:ID[@schemeID="0002"]'), 1, MaxStrLen(GLN));
        EDocumentPurchaseHeader."Customer GLN" := GLN;
        CustomerAddress := EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:PostalTradeAddress/ram:LineOne');
        EDocumentPurchaseHeader."Customer Address" := CopyStr(CustomerAddress, 1, MaxStrLen(EDocumentPurchaseHeader."Customer Address"));
        EDocumentPurchaseHeader."Customer Address Recipient" := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:DefinedTradeContact/ram:PersonName'), 1, MaxStrLen(EDocumentPurchaseHeader."Customer Address Recipient"));
        EDocumentPurchaseHeader."Billing Address" := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:PostalTradeAddress/ram:CityName'), 1, MaxStrLen(EDocumentPurchaseHeader."Billing Address"));
        EDocumentPurchaseHeader."Billing Address Recipient" := CopyStr(EDocumentXMLHelper.GetNodeValue(ZUGFeRDXml, XmlNamespaces, '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:ApplicableHeaderTradeAgreement/ram:BuyerTradeParty/ram:PostalTradeAddress/ram:PostcodeCode'), 1, MaxStrLen(EDocumentPurchaseHeader."Billing Address Recipient"));
    end;

    local procedure EvaluateZUGFeRDDate(DateString: Text): Date
    var
        Day: Integer;
        Month: Integer;
        Year: Integer;
        ResultDate: Date;
    begin
        if StrLen(DateString) <> 8 then
            exit(0D);

        if not Evaluate(Year, CopyStr(DateString, 1, 4)) then
            exit(0D);
        if not Evaluate(Month, CopyStr(DateString, 5, 2)) then
            exit(0D);
        if not Evaluate(Day, CopyStr(DateString, 7, 2)) then
            exit(0D);

        // Validate the date by converting back and forth
        ResultDate := DMY2Date(Day, Month, Year);
        if (Date2DMY(ResultDate, 1) <> Day) or (Date2DMY(ResultDate, 2) <> Month) or (Date2DMY(ResultDate, 3) <> Year) then
            exit(0D); // Invalid date

        exit(ResultDate);
    end;

    local procedure InsertZUGFeRDPurchaseLines(ZugferdXML: XmlDocument; XmlNamespaces: XmlNamespaceManager; EDocumentEntryNo: Integer)
    var
        EDocumentPurchaseLine: Record "E-Document Purchase Line";
        NewLineXML: XmlDocument;
        LineXMLList: XmlNodeList;
        LineXMLNode: XmlNode;
        LineItemPathLbl: Label '/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction/ram:IncludedSupplyChainTradeLineItem', Locked = true;
    begin
        if not ZugferdXML.SelectNodes(LineItemPathLbl, XmlNamespaces, LineXMLList) then
            exit;

        foreach LineXMLNode in LineXMLList do begin
            Clear(EDocumentPurchaseLine);
            EDocumentPurchaseLine.Validate("E-Document Entry No.", EDocumentEntryNo);
            EDocumentPurchaseLine."Line No." := EDocumentPurchaseLine.GetNextLineNo(EDocumentEntryNo);
            NewLineXML.ReplaceNodes(LineXMLNode);
            PopulateZUGFeRDPurchaseLine(NewLineXML, XmlNamespaces, EDocumentPurchaseLine);
            EDocumentPurchaseLine.Insert();
        end;
    end;

    local procedure PopulateZUGFeRDPurchaseLine(LineXML: XmlDocument; XmlNamespaces: XmlNamespaceManager; var EDocumentPurchaseLine: Record "E-Document Purchase Line")
    var
        DateValue: Date;
        TempText: Text;
        TempCode: Code[10];
    begin
        SetStringValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedTradeProduct/ram:SellerAssignedID', MaxStrLen(EDocumentPurchaseLine."Product Code"), TempText);
        if TempText <> '' then
            EDocumentPurchaseLine."Product Code" := CopyStr(TempText, 1, MaxStrLen(EDocumentPurchaseLine."Product Code"));
        if EDocumentPurchaseLine."Product Code" = '' then begin
            SetStringValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedTradeProduct/ram:GlobalID', MaxStrLen(EDocumentPurchaseLine."Product Code"), TempText);
            if TempText <> '' then
                EDocumentPurchaseLine."Product Code" := CopyStr(TempText, 1, MaxStrLen(EDocumentPurchaseLine."Product Code"));
        end;
        if EDocumentPurchaseLine."Product Code" = '' then begin
            SetStringValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedTradeProduct/ram:BuyerAssignedID', MaxStrLen(EDocumentPurchaseLine."Product Code"), TempText);
            if TempText <> '' then
                EDocumentPurchaseLine."Product Code" := CopyStr(TempText, 1, MaxStrLen(EDocumentPurchaseLine."Product Code"));
        end;
        SetStringValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedTradeProduct/ram:Name', MaxStrLen(EDocumentPurchaseLine.Description), TempText);
        if TempText <> '' then
            EDocumentPurchaseLine.Description := CopyStr(TempText, 1, MaxStrLen(EDocumentPurchaseLine.Description));
        if EDocumentPurchaseLine.Description = '' then begin
            SetStringValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedTradeProduct/ram:Description', MaxStrLen(EDocumentPurchaseLine.Description), TempText);
            if TempText <> '' then
                EDocumentPurchaseLine.Description := CopyStr(TempText, 1, MaxStrLen(EDocumentPurchaseLine.Description));
        end;
        SetNumberValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeDelivery/ram:BilledQuantity', EDocumentPurchaseLine.Quantity);
        SetStringValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeDelivery/ram:BilledQuantity/@unitCode', MaxStrLen(EDocumentPurchaseLine."Unit of Measure"), TempText);
        if TempText <> '' then
            EDocumentPurchaseLine."Unit of Measure" := CopyStr(TempText, 1, MaxStrLen(EDocumentPurchaseLine."Unit of Measure"));
        SetNumberValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount', EDocumentPurchaseLine."Sub Total");
        SetNumberValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeAgreement/ram:NetPriceProductTradePrice/ram:ChargeAmount', EDocumentPurchaseLine."Unit Price");
        if EDocumentPurchaseLine."Unit Price" = 0 then
            SetNumberValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeAgreement/ram:GrossPriceProductTradePrice/ram:ChargeAmount', EDocumentPurchaseLine."Unit Price");
        SetNumberValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeAllowanceCharge/ram:ActualAmount', EDocumentPurchaseLine."Total Discount");
        SetNumberValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent', EDocumentPurchaseLine."VAT Rate");
        SetStringValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount/@currencyID', MaxStrLen(TempCode), TempText);
        if TempText <> '' then
            EDocumentPurchaseLine."Currency Code" := CopyStr(TempText, 1, MaxStrLen(EDocumentPurchaseLine."Currency Code"));
        if TrySetDateValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeDelivery/ram:RequestedDeliverySupplyChainEvent/ram:OccurrenceDateTime/udt:DateTimeString', DateValue) then EDocumentPurchaseLine.Date := DateValue;
        if (EDocumentPurchaseLine.Date = 0D) and TrySetDateValueInField(LineXML, XmlNamespaces, 'ram:IncludedSupplyChainTradeLineItem/ram:SpecifiedLineTradeAgreement/ram:RequestedDeliverySupplyChainEvent/ram:OccurrenceDateTime/udt:DateTimeString', DateValue) then
            EDocumentPurchaseLine.Date := DateValue;
    end;

    local procedure SetStringValueInField(XMLDocument: XmlDocument; XMLNamespaces: XmlNamespaceManager; Path: Text; MaxLength: Integer; var Field: Text)
    var
        XMLNode: XmlNode;
    begin
        if not XMLDocument.SelectSingleNode(Path, XMLNamespaces, XMLNode) then
            exit;

        if XMLNode.IsXmlElement() then begin
            Field := CopyStr(XMLNode.AsXmlElement().InnerText(), 1, MaxLength);
            exit;
        end;

        if XMLNode.IsXmlAttribute() then begin
            Field := CopyStr(XMLNode.AsXmlAttribute().Value(), 1, MaxLength);
            exit;
        end;
    end;

    local procedure SetNumberValueInField(XMLDocument: XmlDocument; XMLNamespaces: XmlNamespaceManager; Path: Text; var DecimalValue: Decimal)
    var

        XMLNode: XmlNode;
    begin
        if not XMLDocument.SelectSingleNode(Path, XMLNamespaces, XMLNode) then
            exit;

        if XMLNode.AsXmlElement().InnerText() <> '' then
            Evaluate(DecimalValue, XMLNode.AsXmlElement().InnerText(), 9);
    end;

    local procedure TrySetDateValueInField(XMLDocument: XmlDocument; XMLNamespaces: XmlNamespaceManager; Path: Text; var DateValue: Date): Boolean
    var
        XMLNode: XmlNode;
        DateText: Text;
    begin
        if not XMLDocument.SelectSingleNode(Path, XMLNamespaces, XMLNode) then
            exit(false);

        DateText := XMLNode.AsXmlElement().InnerText();
        if DateText = '' then
            exit(false);

        DateValue := EvaluateZUGFeRDDate(DateText);
        exit(DateValue <> 0D);
    end;

    local procedure IsDocumentTypeSupported(DocumentTypeCode: Text; EDocumentType: Enum "E-Document Type"): Boolean
    begin
        if DocumentTypeCode = '' then
            exit(false);

        case DocumentTypeCode of
            '380', '384', '751', '877': // Invoice types
                begin
                    EDocumentType := "E-Document Type"::"Purchase Invoice";
                    exit(true);
                end;
            '381', '261': // Credit note types
                begin
                    EDocumentType := "E-Document Type"::"Purchase Credit Memo";
                    exit(true);
                end;
        end;
    end;
}
