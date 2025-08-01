// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Sales.Customer;

/// <summary>
/// Codeunit Shpfy Company API (ID 30286).
/// </summary>
codeunit 30286 "Shpfy Company API"
{
    Access = Internal;
    Permissions = tabledata Customer = rim;

    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        CommunicationMgt: Codeunit "Shpfy Communication Mgt.";
        JsonHelper: Codeunit "Shpfy Json Helper";
        MetafieldAPI: Codeunit "Shpfy Metafield API";

    internal procedure CreateCompany(var ShopifyCompany: Record "Shpfy Company"; var CompanyLocation: Record "Shpfy Company Location"; ShopifyCustomer: Record "Shpfy Customer"): Boolean
    var
        JItem: JsonToken;
        JResponse: JsonToken;
        JLocations: JsonArray;
        GraphQuery: Text;
        CompanyContactId: BigInteger;
        CompanyContactRoles: Dictionary of [Text, BigInteger];
    begin
        GraphQuery := CreateCompanyGraphQLQuery(ShopifyCompany, CompanyLocation);
        JResponse := CommunicationMgt.ExecuteGraphQL(GraphQuery);
        if JResponse.SelectToken('$.data.companyCreate.company', JItem) then
            if JItem.IsObject then begin
                ShopifyCompany.Id := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JItem, 'id'));
                if JsonHelper.GetJsonArray(JResponse, JLocations, 'data.companyCreate.company.locations.edges') then
                    if JLocations.Count = 1 then
                        if JLocations.Get(0, JItem) then begin
                            ShopifyCompany."Location Id" := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JItem, 'node.id'));
                            CompanyLocation.Id := ShopifyCompany."Location Id";
                        end;
                if JsonHelper.GetJsonArray(JResponse, JLocations, 'data.companyCreate.company.contactRoles.edges') then
                    foreach JItem in JLocations do
                        CompanyContactRoles.Add(JsonHelper.GetValueAsText(JItem, 'node.name'), CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JItem, 'node.id')));
            end;
        if ShopifyCompany.Id > 0 then begin
            CompanyContactId := AssignCompanyMainContact(ShopifyCompany.Id, ShopifyCustomer.Id, ShopifyCompany."Location Id", CompanyContactRoles);
            ShopifyCompany."Main Contact Id" := CompanyContactId;
            exit(true);
        end else
            exit(false);
    end;

    internal procedure UpdateCompany(var ShopifyCompany: Record "Shpfy Company")
    var
        JItem: JsonToken;
        JResponse: JsonToken;
        GraphQuery: Text;
        UpdateCustIdErr: Label 'Wrong updated Customer Id';
    begin
        GraphQuery := CreateGraphQueryUpdateCompany(ShopifyCompany);

        if GraphQuery <> '' then begin
            JResponse := CommunicationMgt.ExecuteGraphQL(GraphQuery);
            if JResponse.SelectToken('$.data.companyUpdate.company', JItem) then
                if JItem.IsObject then begin
                    if ShopifyCompany.Id <> CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JItem, 'id')) then
                        Error(UpdateCustIdErr);
                    ShopifyCompany."Updated At" := JsonHelper.GetValueAsDateTime(JItem, 'updatedAt');
                end;
        end;
    end;

    internal procedure UpdateCompanyLocation(var CompanyLocation: Record "Shpfy Company Location")
    var
        GraphQuery: Text;
        JResponse: JsonToken;
    begin
        GraphQuery := CreateGraphQueryUpdateLocation(CompanyLocation);
        if GraphQuery <> '' then
            JResponse := CommunicationMgt.ExecuteGraphQL(GraphQuery);

        UpdateCompanyLocationTaxId(CompanyLocation);
        UpdateCompanyLocationPaymentTerms(CompanyLocation)
    end;

    internal procedure SetShop(ShopifyShop: Record "Shpfy Shop")
    begin
        this.Shop := ShopifyShop;
        CommunicationMgt.SetShop(ShopifyShop);
        MetafieldAPI.SetShop(ShopifyShop);
    end;

    local procedure AddFieldToGraphQuery(var GraphQuery: TextBuilder; FieldName: Text; ValueAsVariant: Variant): Boolean
    begin
        exit(AddFieldToGraphQuery(GraphQuery, FieldName, ValueAsVariant, true));
    end;

    local procedure AddFieldToGraphQuery(var GraphQuery: TextBuilder; FieldName: Text; ValueAsVariant: Variant; ValueAsString: Boolean): Boolean
    begin
        GraphQuery.Append(FieldName);
        if ValueAsString then
            GraphQuery.Append(': \"')
        else
            GraphQuery.Append(': ');
        GraphQuery.Append(CommunicationMgt.EscapeGraphQLData(Format(ValueAsVariant)));
        if ValueAsString then
            GraphQuery.Append('\", ')
        else
            GraphQuery.Append(', ');
        exit(true);
    end;

    internal procedure CreateCompanyGraphQLQuery(var ShopifyCompany: Record "Shpfy Company"; CompanyLocation: Record "Shpfy Company Location"): Text
    var
        GraphQuery: TextBuilder;
        PaymentTermsTemplateIdTxt: Label 'gid://shopify/PaymentTermsTemplate/%1', Comment = '%1 = Payment Terms Template Id', Locked = true;
    begin
        GraphQuery.Append('{"query":"mutation {companyCreate(input: {company: {');
        if ShopifyCompany.Name <> '' then
            AddFieldToGraphQuery(GraphQuery, 'name', ShopifyCompany.Name);
        if ShopifyCompany."External Id" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'externalId', ShopifyCompany."External Id");
        GraphQuery.Remove(GraphQuery.Length - 1, 2);
        GraphQuery.Append('}, companyLocation: {billingSameAsShipping: true,');
        AddFieldToGraphQuery(GraphQuery, 'name', CompanyLocation.Name);
        if CompanyLocation."Phone No." <> '' then
            AddFieldToGraphQuery(GraphQuery, 'phone', CompanyLocation."Phone No.");
        if CompanyLocation."Tax Registration Id" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'taxRegistrationId', CompanyLocation."Tax Registration Id");
        GraphQuery.Append('shippingAddress: {');
        AddFieldToGraphQuery(GraphQuery, 'address1', CompanyLocation.Address);
        if CompanyLocation."Address 2" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'address2', CompanyLocation."Address 2");
        if CompanyLocation.Zip <> '' then
            AddFieldToGraphQuery(GraphQuery, 'zip', CompanyLocation.Zip);
        if CompanyLocation.City <> '' then
            AddFieldToGraphQuery(GraphQuery, 'city', CompanyLocation.City);
        if CompanyLocation."Phone No." <> '' then
            AddFieldToGraphQuery(GraphQuery, 'phone', CompanyLocation."Phone No.");
        if CompanyLocation."Country/Region Code" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'countryCode', CompanyLocation."Country/Region Code", false);
        if CompanyLocation."Province Code" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'zoneCode', CompanyLocation."Province Code");
        if CompanyLocation.Recipient <> '' then
            AddFieldToGraphQuery(GraphQuery, 'recipient', CompanyLocation.Recipient);
        if CompanyLocation."Shpfy Payment Terms Id" <> 0 then begin
            GraphQuery.Append('}, buyerExperienceConfiguration: {');
            AddFieldToGraphQuery(GraphQuery, 'paymentTermsTemplateId', StrSubstNo(PaymentTermsTemplateIdTxt, CompanyLocation."Shpfy Payment Terms Id"));
        end;
        GraphQuery.Remove(GraphQuery.Length - 1, 2);
        GraphQuery.Append('}}}) {company {id, name, locations(first: 1) {edges {node {id, name}}}, contactRoles(first:10) {edges {node {id,name}}}}, userErrors {field, message}}}"}');
        exit(GraphQuery.ToText());
    end;

    local procedure AssignCompanyMainContact(CompanyId: BigInteger; CustomerId: BigInteger; LocationId: BigInteger; CompanyContactRoles: Dictionary of [Text, BigInteger]): BigInteger
    var
        GraphQLType: Enum "Shpfy GraphQL Type";
        JResponse: JsonToken;
        Parameters: Dictionary of [Text, Text];
        CompanyContactId: BigInteger;
    begin
        Parameters.Add('CompanyId', Format(CompanyId));
        Parameters.Add('CustomerId', Format(CustomerId));
        JResponse := CommunicationMgt.ExecuteGraphQL(GraphQLType::CompanyAssignCustomerAsContact, Parameters);
        CompanyContactId := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JResponse, 'data.companyAssignCustomerAsContact.companyContact.id'));
        if CompanyContactId > 0 then begin
            Clear(Parameters);
            Parameters.Add('CompanyId', Format(CompanyId));
            Parameters.Add('CompanyContactId', Format(CompanyContactId));
            JResponse := CommunicationMgt.ExecuteGraphQL(GraphQLType::CompanyAssignMainContact, Parameters);
            AssignCompanyContactRoles(CompanyContactId, LocationId, CompanyContactRoles);
        end;
        exit(CompanyContactId);
    end;

    local procedure AssignCompanyContactRoles(CompanyContactId: BigInteger; LocationId: BigInteger; CompanyContactRoles: Dictionary of [Text, BigInteger])
    var
        GraphQLType: Enum "Shpfy GraphQL Type";
        JResponse: JsonToken;
        Parameters: Dictionary of [Text, Text];
    begin
        if Shop."Default Contact Permission" = "Shpfy Default Cont. Permission"::"No Permission" then
            exit
        else begin
            Parameters.Add('LocationId', Format(LocationId));
            Parameters.Add('ContactId', Format(CompanyContactId));
            Parameters.Add('ContactRoleId', Format(CompanyContactRoles.Get(Enum::"Shpfy Default Cont. Permission".Names().Get(Enum::"Shpfy Default Cont. Permission".Ordinals().IndexOf(Shop."Default Contact Permission".AsInteger())))));
            JResponse := CommunicationMgt.ExecuteGraphQL(GraphQLType::CompanyAssignContactRole, Parameters);
        end;
    end;

    internal procedure CreateGraphQueryUpdateCompany(var ShopifyCompany: Record "Shpfy Company"): Text
    var
        xShopifyCompany: Record "Shpfy Company";
        HasChange: Boolean;
        GraphQuery: TextBuilder;
        CompanyIdTxt: Label 'gid://shopify/Company/%1', Comment = '%1 = Company Id', Locked = true;
    begin
        xShopifyCompany.Get(ShopifyCompany.Id);
        GraphQuery.Append('{"query":"mutation {companyUpdate(companyId: \"' + StrSubstNo(CompanyIdTxt, ShopifyCompany.Id) + '\", input: {');
        if ShopifyCompany.Name <> xShopifyCompany.Name then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'name', ShopifyCompany.Name);
        if ShopifyCompany."External Id" <> xShopifyCompany."External Id" then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'externalId', ShopifyCompany."External Id");
        if ShopifyCompany.GetNote() <> xShopifyCompany.GetNote() then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'note', CommunicationMgt.EscapeGraphQLData(ShopifyCompany.GetNote()));

        if HasChange then begin
            GraphQuery.Remove(GraphQuery.Length - 1, 2);
            GraphQuery.Append('}) {company {id, updatedAt}, userErrors {field, message}}}"}');
            exit(GraphQuery.ToText());
        end;
    end;

    internal procedure CreateGraphQueryUpdateLocation(var CompanyLocation: Record "Shpfy Company Location"): Text
    var
        xCompanyLocation: Record "Shpfy Company Location";
        HasChange: Boolean;
        GraphQuery: TextBuilder;
        CompanyLocationIdTxt: Label 'gid://shopify/CompanyLocation/%1', Comment = '%1 = Company Location Id', Locked = true;
    begin
        xCompanyLocation.Get(CompanyLocation.Id);
        GraphQuery.Append('{"query":"mutation {companyLocationAssignAddress(locationId: \"' + StrSubstNo(CompanyLocationIdTxt, CompanyLocation.Id) + '\", addressTypes: [BILLING,SHIPPING] address: {');
        if CompanyLocation.Address <> xCompanyLocation.Address then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'address1', CompanyLocation.Address);
        if CompanyLocation."Address 2" <> xCompanyLocation."Address 2" then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'address2', CompanyLocation."Address 2");
        if CompanyLocation.Zip <> xCompanyLocation.Zip then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'zip', CompanyLocation.Zip);
        if CompanyLocation.City <> xCompanyLocation.City then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'city', CompanyLocation.City);
        if CompanyLocation."Phone No." <> xCompanyLocation."Phone No." then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'phone', CompanyLocation."Phone No.");
        if CompanyLocation."Country/Region Code" <> xCompanyLocation."Country/Region Code" then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'countryCode', CompanyLocation."Country/Region Code", false);
        if CompanyLocation."Province Code" <> xCompanyLocation."Province Code" then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'zoneCode', CompanyLocation."Province Code");
        if CompanyLocation.Recipient <> xCompanyLocation.Recipient then
            HasChange := AddFieldToGraphQuery(GraphQuery, 'recipient', CompanyLocation.Recipient);
        GraphQuery.Remove(GraphQuery.Length - 1, 2);

        if HasChange then begin
            GraphQuery.Append('}) {addresses {id}, userErrors {field, message}}}"}');
            exit(GraphQuery.ToText());
        end;
    end;

    internal procedure UpdateCompanyLocationTaxId(var CompanyLocation: Record "Shpfy Company Location")
    var
        xCompanyLocation: Record "Shpfy Company Location";
        GraphQLType: Enum "Shpfy GraphQL Type";
        Parameters: Dictionary of [Text, Text];
    begin
        xCompanyLocation.Get(CompanyLocation.Id);
        if CompanyLocation."Tax Registration Id" = xCompanyLocation."Tax Registration Id" then
            exit;

        Parameters.Add('LocationId', Format(CompanyLocation.Id));
        Parameters.Add('TaxId', Format(CompanyLocation."Tax Registration Id"));
        CommunicationMgt.ExecuteGraphQL(GraphQLType::CreateCompanyLocationTaxId, Parameters);
    end;

    internal procedure UpdateCompanyLocationPaymentTerms(var CompanyLocation: Record "Shpfy Company Location")
    var
        xCompanyLocation: Record "Shpfy Company Location";
        GraphQLType: Enum "Shpfy GraphQL Type";
        Parameters: Dictionary of [Text, Text];
    begin
        xCompanyLocation.Get(CompanyLocation.Id);
        if CompanyLocation."Shpfy Payment Terms Id" = xCompanyLocation."Shpfy Payment Terms Id" then
            exit;

        Parameters.Add('LocationId', Format(CompanyLocation.Id));
        Parameters.Add('PaymentTermsId', Format(CompanyLocation."Shpfy Payment Terms Id"));
        CommunicationMgt.ExecuteGraphQL(GraphQLType::UpdateCompanyLocationPaymentTerms, Parameters);
    end;

    internal procedure RetrieveShopifyCompanyIds(var CompanyIds: Dictionary of [BigInteger, DateTime])
    var
        Id: BigInteger;
        UpdatedAt: DateTime;
        JCompanies: JsonArray;
        JNode: JsonObject;
        JItem: JsonToken;
        JResponse: JsonToken;
        Cursor: Text;
        GraphQLType: Enum "Shpfy GraphQL Type";
        Parameters: Dictionary of [Text, Text];
        LastSync: DateTime;
    begin
        GraphQLType := GraphQLType::GetCompanyIds;
        LastSync := Shop.GetLastSyncTime("Shpfy Synchronization Type"::Companies);
        Parameters.Add('LastSync', Format(LastSync, 0, 9));
        repeat
            JResponse := CommunicationMgt.ExecuteGraphQL(GraphQLType, Parameters);
            if JsonHelper.GetJsonArray(JResponse, JCompanies, 'data.companies.edges') then begin
                foreach JItem in JCompanies do begin
                    Cursor := JsonHelper.GetValueAsText(JItem.AsObject(), 'cursor');
                    if JsonHelper.GetJsonObject(JItem.AsObject(), JNode, 'node') then begin
                        Id := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JNode, 'id'));
                        UpdatedAt := JsonHelper.GetValueAsDateTime(JNode, 'updatedAt');
                        CompanyIds.Add(Id, UpdatedAt);
                    end;
                end;
                if Parameters.ContainsKey('After') then
                    Parameters.Set('After', Cursor)
                else
                    Parameters.Add('After', Cursor);
                GraphQLType := GraphQLType::GetNextCompanyIds;
            end;
        until not JsonHelper.GetValueAsBoolean(JResponse, 'data.companies.pageInfo.hasNextPage');
    end;

    internal procedure RetrieveShopifyCompany(var ShopifyCompany: Record "Shpfy Company"; var TempShopifyCustomer: Record "Shpfy Customer" temporary): Boolean
    var
        GraphQLType: Enum "Shpfy GraphQL Type";
        Parameters: Dictionary of [Text, Text];
        JCompany: JsonObject;
        JCustomer: JsonObject;
        JResponse: JsonToken;
    begin
        if ShopifyCompany.Id = 0 then
            exit(false);

        Parameters.Add('CompanyId', Format(ShopifyCompany.Id));
        JResponse := CommunicationMgt.ExecuteGraphQL(GraphQLType::GetCompany, Parameters);

        if not JsonHelper.GetJsonObject(JResponse, JCustomer, 'data.company.mainContact') then
            exit(false)
        else
            UpdateShopifyCustomerFields(TempShopifyCustomer, JCustomer);

        if JsonHelper.GetJsonObject(JResponse, JCompany, 'data.company') then
            exit(UpdateShopifyCompanyFields(ShopifyCompany, JCompany));
    end;

    internal procedure UpdateShopifyCustomerFields(var TempShopifyCustomer: Record "Shpfy Customer" temporary; JCustomer: JsonObject)
    var
        PhoneNo: Text;
    begin
        Clear(TempShopifyCustomer);
        TempShopifyCustomer."Shop Id" := Shop."Shop Id";
        TempShopifyCustomer.Id := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JCustomer, 'customer.id'));
        TempShopifyCustomer."First Name" := CopyStr(JsonHelper.GetValueAsText(JCustomer, 'customer.firstName', MaxStrLen(TempShopifyCustomer."First Name")), 1, MaxStrLen(TempShopifyCustomer."First Name"));
        TempShopifyCustomer."Last Name" := CopyStr(JsonHelper.GetValueAsText(JCustomer, 'customer.lastName', MaxStrLen(TempShopifyCustomer."Last Name")), 1, MaxStrLen(TempShopifyCustomer."Last Name"));
        TempShopifyCustomer.Email := CopyStr(JsonHelper.GetValueAsText(JCustomer, 'customer.defaultEmailAddress.emailAddress', MaxStrLen(TempShopifyCustomer.Email)), 1, MaxStrLen(TempShopifyCustomer.Email));
        PhoneNo := JsonHelper.GetValueAsText(JCustomer, 'customer.defaultPhoneNumber.phoneNumber');
        PhoneNo := DelChr(PhoneNo, '=', DelChr(PhoneNo, '=', '1234567890/+ .()'));
        TempShopifyCustomer."Phone No." := CopyStr(PhoneNo, 1, MaxStrLen(TempShopifyCustomer."Phone No."));
    end;

    internal procedure UpdateShopifyCompanyFields(var ShopifyCompany: Record "Shpfy Company"; JCompany: JsonObject) Result: Boolean
    var
        UpdatedAt: DateTime;
        JMetafields: JsonArray;
        OutStream: OutStream;
    begin
        UpdatedAt := JsonHelper.GetValueAsDateTime(JCompany, 'updatedAt');
        if UpdatedAt <= ShopifyCompany."Updated At" then
            exit(false);
        Result := true;

        ShopifyCompany."Updated At" := UpdatedAt;
        ShopifyCompany."Created At" := JsonHelper.GetValueAsDateTime(JCompany, 'createdAt');
        ShopifyCompany."Main Contact Id" := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JCompany, 'mainContact.id'));
        ShopifyCompany."Main Contact Customer Id" := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JCompany, 'mainContact.customer.id'));
        ShopifyCompany.Name := CopyStr(JsonHelper.GetValueAsText(JCompany, 'name', MaxStrLen(ShopifyCompany.Name)), 1, MaxStrLen(ShopifyCompany.Name));
        ShopifyCompany."External Id" := CopyStr(JsonHelper.GetValueAsText(JCompany, 'externalId', MaxStrLen(ShopifyCompany."External Id")), 1, MaxStrLen(ShopifyCompany."External Id"));
        if JsonHelper.GetValueAsText(JCompany, 'note') <> '' then begin
            Clear(ShopifyCompany.Note);
            ShopifyCompany.Note.CreateOutStream(OutStream, TextEncoding::UTF8);
            OutStream.WriteText(JsonHelper.GetValueAsText(JCompany, 'note'));
        end else
            Clear(ShopifyCompany.Note);
        ShopifyCompany.Modify();

        if JsonHelper.GetJsonArray(JCompany, JMetafields, 'metafields.edges') then
            MetafieldAPI.UpdateMetafieldsFromShopify(JMetafields, Database::"Shpfy Company", ShopifyCompany.Id);
    end;

    internal procedure UpdateShopifyCompanyLocation(var ShopifyCompany: Record "Shpfy Company")
    var
        GraphQLType: Enum "Shpfy GraphQL Type";
        Parameters: Dictionary of [Text, Text];
        JResponse: JsonToken;
        Cursor: Text;
        IsDefaultCompanyLocation: Boolean;
    begin
        GraphQLType := "Shpfy GraphQL Type"::GetCompanyLocations;
        Parameters.Add('CompanyId', Format(ShopifyCompany.Id));
        IsDefaultCompanyLocation := true;
        repeat
            JResponse := CommunicationMgt.ExecuteGraphQL(GraphQLType, Parameters);
            if JResponse.IsObject() then
                if ExtractShopifyCompanyLocations(ShopifyCompany, JResponse.AsObject(), Cursor, IsDefaultCompanyLocation) then begin
                    if Parameters.ContainsKey('After') then
                        Parameters.Set('After', Cursor)
                    else
                        Parameters.Add('After', Cursor);
                    GraphQLType := "Shpfy GraphQL Type"::GetNextCompanyLocations;
                end else
                    break;
        until not JsonHelper.GetValueAsBoolean(JResponse, 'data.companyLocations.pageInfo.hasNextPage');
    end;

    /// <summary>
    /// Creates a new company location in Shopify from a Business Central customer.
    /// This is the main entry point for exporting customers as company locations.
    /// </summary>
    /// <param name="Customer">The Business Central customer to export as a company location.</param>
    /// <remarks>
    /// This procedure performs validation to ensure the customer is not already exported as either a company or location.
    /// If the customer is already exported, the record is skipped and logged.
    /// The procedure retrieves the parent company and calls CreateCustomerAsCompanyLocation to perform the actual creation.
    /// </remarks>
    internal procedure CreateCompanyLocation(Customer: Record Customer)
    var
        ShopifyCompany: Record "Shpfy Company";
        CompanyLocation: Record "Shpfy Company Location";
        SkippedRecord: Codeunit "Shpfy Skipped Record";
        CustomerAlreadyExportedCompanyLbl: Label 'Customer %1 is already exported as a company', Comment = '%1 = Customer No.';
        CustomerAlreadyExportedLocationLbl: Label 'Customer %1 is already exported as a location', Comment = '%1 = Customer No.';
    begin
        ShopifyCompany.SetCurrentKey("Customer SystemId");
        ShopifyCompany.SetRange("Customer SystemId", Customer.SystemId);
        if not ShopifyCompany.IsEmpty() then begin
            SkippedRecord.LogSkippedRecord(Customer.RecordId, StrSubstNo(CustomerAlreadyExportedCompanyLbl, Customer."No."), Shop);
            exit;
        end;
        CompanyLocation.SetRange("Customer Id", Customer.SystemId);
        if not CompanyLocation.IsEmpty() then begin
            SkippedRecord.LogSkippedRecord(Customer.RecordId, StrSubstNo(CustomerAlreadyExportedLocationLbl, Customer."No."), Shop);
            exit;
        end;
        CreateCustomerAsCompanyLocation(Customer, this.Company);
    end;

    internal procedure SetCompany(ShopifyCompany: Record "Shpfy Company")
    begin
        this.Company := ShopifyCompany;
    end;

    /// <summary>
    /// Creates a customer as a company location in Shopify using GraphQL API.
    /// This procedure handles the API communication and error processing.
    /// </summary>
    /// <param name="CompanyLocation">The Shopify company location record containing the data to be sent to Shopify.</param>
    /// <param name="Customer">The Business Central customer record used to populate additional fields.</param>
    /// <remarks>
    /// This procedure:
    /// - Fills the Shopify company location with data from the customer
    /// - Constructs GraphQL parameters for the companyLocationCreate mutation
    /// - Sends the request to Shopify API
    /// - Processes the response and handles any user errors
    /// - If successful, calls CreateCustomerLocation to update the local record with Shopify data
    /// 
    /// The procedure supports both billing and shipping addresses, with billing address used for both when billingSameAsShipping is true.
    /// Error handling includes field-specific error messages from Shopify API.
    /// </remarks>
    local procedure CreateCustomerAsCompanyLocation(Customer: Record Customer; ShopifyCompany: Record "Shpfy Company")
    var
        CompanyLocation: Record "Shpfy Company Location";
        CompanyExport: Codeunit "Shpfy Company Export";
        GraphQuery: TextBuilder;
        JResponse: JsonToken;
        JCompanyLocation: JsonToken;
        CompanyIdTxt: Label 'gid://shopify/Company/%1', Comment = '%1 = Company Id', Locked = true;
        PaymentTermsTemplateIdTxt: Label 'gid://shopify/PaymentTermsTemplate/%1', Comment = '%1 = Payment Terms Template Id', Locked = true;
    begin
        CompanyExport.SetShop(this.Shop);
        CompanyExport.FillInShopifyCompanyLocation(Customer, CompanyLocation);

        GraphQuery.Append('{"query": "mutation { companyLocationCreate( companyId: \"' + StrSubstNo(CompanyIdTxt, ShopifyCompany.Id) + '\", input: {');

        if ShopifyCompany."External Id" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'externalId', ShopifyCompany."External Id");
        if CompanyLocation.Name <> '' then
            AddFieldToGraphQuery(GraphQuery, 'name', CompanyLocation.Name);
        if CompanyLocation."Phone No." <> '' then
            AddFieldToGraphQuery(GraphQuery, 'phone', CompanyLocation."Phone No.");
        if CompanyLocation."Tax Registration Id" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'taxRegistrationId', CompanyLocation."Tax Registration Id");
        GraphQuery.Append('taxExempt: false, billingSameAsShipping: true, shippingAddress: {');
        if CompanyLocation.Address <> '' then
            AddFieldToGraphQuery(GraphQuery, 'address1', CompanyLocation.Address);
        if CompanyLocation."Address 2" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'address2', CompanyLocation."Address 2");
        if CompanyLocation.City <> '' then
            AddFieldToGraphQuery(GraphQuery, 'city', CompanyLocation.City);
        if CompanyLocation."Country/Region Code" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'countryCode', CompanyLocation."Country/Region Code", false);
        if CompanyLocation."Phone No." <> '' then
            AddFieldToGraphQuery(GraphQuery, 'phone', CompanyLocation."Phone No.");
        if CompanyLocation."Province Code" <> '' then
            AddFieldToGraphQuery(GraphQuery, 'zoneCode', CompanyLocation."Province Code");
        if CompanyLocation.Zip <> '' then
            AddFieldToGraphQuery(GraphQuery, 'zip', CompanyLocation.Zip);
        if CompanyLocation.Recipient <> '' then
            AddFieldToGraphQuery(GraphQuery, 'recipient', CompanyLocation.Recipient);
        GraphQuery.Append('}, buyerExperienceConfiguration: { checkoutToDraft: false, editableShippingAddress: false, ');
        if CompanyLocation."Shpfy Payment Terms Id" <> 0 then
            AddFieldToGraphQuery(GraphQuery, 'paymentTermsTemplateId', StrSubstNo(PaymentTermsTemplateIdTxt, CompanyLocation."Shpfy Payment Terms Id"));
        GraphQuery.Remove(GraphQuery.Length - 1, 2);
        GraphQuery.Append('}}) { companyLocation { id name billingAddress { address1 address2 city countryCode phone province recipient zip zoneCode } ');
        GraphQuery.Append('shippingAddress { address1 address2 city countryCode phone province recipient zip zoneCode } ');
        GraphQuery.Append('buyerExperienceConfiguration { paymentTermsTemplate { id } checkoutToDraft editableShippingAddress } taxRegistrationId taxExemptions } ');
        GraphQuery.Append('userErrors { field message } } }"}');

        JResponse := CommunicationMgt.ExecuteGraphQL(GraphQuery.ToText());
        if JResponse.SelectToken('$.data.companyLocationCreate.companyLocation', JCompanyLocation) then
            if not JsonHelper.IsTokenNull(JCompanyLocation) then
                CreateCustomerLocation(JCompanyLocation.AsObject(), ShopifyCompany, Customer.SystemId);
    end;

    /// <summary>
    /// Updates the local Shopify company location record with data returned from Shopify API.
    /// This procedure processes the JSON response from a successful company location creation.
    /// </summary>
    /// <param name="JCompanyLocation">JSON object containing the company location data from Shopify API response.</param>
    /// <param name="ShopifyCompany">The parent Shopify company record.</param>
    /// <param name="CustomerId">The GUID of the Business Central customer that was exported.</param>
    /// <remarks>
    /// This procedure:
    /// - Extracts the Shopify-generated ID and creates the initial record
    /// - Populates all address fields from the billingAddress node in the JSON
    /// - Processes phone numbers by removing non-numeric characters except specific symbols
    /// - Updates tax registration ID and payment terms information
    /// - Links the location to both the parent company and the original customer
    /// 
    /// The procedure assumes the JSON structure matches Shopify's companyLocationCreate response format.
    /// All text fields are properly truncated to match the field lengths in the table definition.
    /// </remarks>
    local procedure CreateCustomerLocation(JCompanyLocation: JsonObject; ShopifyCompany: Record "Shpfy Company"; CustomerId: Guid)
    var
        CompanyLocation: Record "Shpfy Company Location";
        CompanyLocationId: BigInteger;
        PhoneNo: Text;
    begin
        CompanyLocationId := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JCompanyLocation, 'id'));
        CompanyLocation.Init();
        CompanyLocation.Id := CompanyLocationId;
        CompanyLocation."Company SystemId" := ShopifyCompany.SystemId;
        CompanyLocation.Name := CopyStr(JsonHelper.GetValueAsText(JCompanyLocation, 'name'), 1, MaxStrLen(CompanyLocation.Name));
        CompanyLocation.Insert(true);

        CompanyLocation.Address := CopyStr(JsonHelper.GetValueAsText(JCompanyLocation, 'billingAddress.address1', MaxStrLen(CompanyLocation.Address)), 1, MaxStrLen(CompanyLocation.Address));
        CompanyLocation."Address 2" := CopyStr(JsonHelper.GetValueAsText(JCompanyLocation, 'billingAddress.address2', MaxStrLen(CompanyLocation."Address 2")), 1, MaxStrLen(CompanyLocation."Address 2"));
        CompanyLocation.Zip := CopyStr(JsonHelper.GetValueAsCode(JCompanyLocation, 'billingAddress.zip', MaxStrLen(CompanyLocation.Zip)), 1, MaxStrLen(CompanyLocation.Zip));
        CompanyLocation.City := CopyStr(JsonHelper.GetValueAsText(JCompanyLocation, 'billingAddress.city', MaxStrLen(CompanyLocation.City)), 1, MaxStrLen(CompanyLocation.City));
        CompanyLocation."Country/Region Code" := CopyStr(JsonHelper.GetValueAsCode(JCompanyLocation, 'billingAddress.countryCode', MaxStrLen(CompanyLocation."Country/Region Code")), 1, MaxStrLen(CompanyLocation."Country/Region Code"));
        CompanyLocation."Province Code" := CopyStr(JsonHelper.GetValueAsText(JCompanyLocation, 'billingAddress.zoneCode', MaxStrLen(CompanyLocation."Province Code")), 1, MaxStrLen(CompanyLocation."Province Code"));
        CompanyLocation."Province Name" := CopyStr(JsonHelper.GetValueAsText(JCompanyLocation, 'billingAddress.province', MaxStrLen(CompanyLocation."Province Name")), 1, MaxStrLen(CompanyLocation."Province Name"));
        PhoneNo := JsonHelper.GetValueAsText(JCompanyLocation, 'billingAddress.phone');
        PhoneNo := CopyStr(DelChr(PhoneNo, '=', DelChr(PhoneNo, '=', '1234567890/+ .()')), 1, MaxStrLen(CompanyLocation."Phone No."));
        CompanyLocation."Phone No." := CopyStr(PhoneNo, 1, MaxStrLen(CompanyLocation."Phone No."));
#pragma warning disable AA0139
        CompanyLocation."Tax Registration Id" := JsonHelper.GetValueAsText(JCompanyLocation, 'taxRegistrationId', MaxStrLen(CompanyLocation."Tax Registration Id"));
#pragma warning restore AA0139
        CompanyLocation.Recipient := CopyStr(JsonHelper.GetValueAsText(JCompanyLocation, 'billingAddress.recipient', MaxStrLen(CompanyLocation.Recipient)), 1, MaxStrLen(CompanyLocation.Recipient));
        CompanyLocation."Shpfy Payment Terms Id" := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JCompanyLocation, 'buyerExperienceConfiguration.paymentTermsTemplate.id'));
        CompanyLocation."Customer Id" := CustomerId;
        CompanyLocation.Modify(true);
    end;

    local procedure ExtractShopifyCompanyLocations(var ShopifyCompany: Record "Shpfy Company"; JResponse: JsonObject; var Cursor: Text; var IsDefaultCompanyLocation: Boolean): Boolean
    var
        CompanyLocation: Record "Shpfy Company Location";
        JLocations: JsonArray;
        JLocation: JsonToken;
        PhoneNo: Text;
        CompanyLocationId: BigInteger;
    begin
        if JsonHelper.GetJsonArray(JResponse, JLocations, 'data.companyLocations.edges') then begin
            foreach JLocation in JLocations do begin
                Cursor := JsonHelper.GetValueAsText(JLocation.AsObject(), 'cursor');
                CompanyLocationId := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JLocation, 'node.id'));
                if IsDefaultCompanyLocation then
                    ShopifyCompany."Location Id" := CompanyLocationId;

                CompanyLocation.SetRange(Id, CompanyLocationId);
                if not CompanyLocation.FindFirst() then begin
                    CompanyLocation.Init();
                    CompanyLocation.Id := CompanyLocationId;
                    CompanyLocation."Company SystemId" := ShopifyCompany.SystemId;
                    CompanyLocation.Name := CopyStr(JsonHelper.GetValueAsText(JLocation, 'node.name'), 1, MaxStrLen(CompanyLocation.Name));
                    CompanyLocation.Insert(true);
                end;

                CompanyLocation.Address := CopyStr(JsonHelper.GetValueAsText(JLocation, 'node.billingAddress.address1', MaxStrLen(CompanyLocation.Address)), 1, MaxStrLen(CompanyLocation.Address));
                CompanyLocation."Address 2" := CopyStr(JsonHelper.GetValueAsText(JLocation, 'node.billingAddress.address2', MaxStrLen(CompanyLocation."Address 2")), 1, MaxStrLen(CompanyLocation."Address 2"));
                CompanyLocation.Zip := CopyStr(JsonHelper.GetValueAsCode(JLocation, 'node.billingAddress.zip', MaxStrLen(CompanyLocation.Zip)), 1, MaxStrLen(CompanyLocation.Zip));
                CompanyLocation.City := CopyStr(JsonHelper.GetValueAsText(JLocation, 'node.billingAddress.city', MaxStrLen(CompanyLocation.City)), 1, MaxStrLen(CompanyLocation.City));
                CompanyLocation."Country/Region Code" := CopyStr(JsonHelper.GetValueAsCode(JLocation, 'node.billingAddress.countryCode', MaxStrLen(CompanyLocation."Country/Region Code")), 1, MaxStrLen(CompanyLocation."Country/Region Code"));
                CompanyLocation."Province Code" := CopyStr(JsonHelper.GetValueAsText(JLocation, 'node.billingAddress.zoneCode', MaxStrLen(CompanyLocation."Province Code")), 1, MaxStrLen(CompanyLocation."Province Code"));
                CompanyLocation."Province Name" := CopyStr(JsonHelper.GetValueAsText(JLocation, 'node.billingAddress.province', MaxStrLen(CompanyLocation."Province Name")), 1, MaxStrLen(CompanyLocation."Province Name"));
                PhoneNo := JsonHelper.GetValueAsText(JLocation, 'node.billingAddress.phone');
                PhoneNo := CopyStr(DelChr(PhoneNo, '=', DelChr(PhoneNo, '=', '1234567890/+ .()')), 1, MaxStrLen(CompanyLocation."Phone No."));
                CompanyLocation."Phone No." := CopyStr(PhoneNo, 1, MaxStrLen(CompanyLocation."Phone No."));
#pragma warning disable AA0139
                CompanyLocation."Tax Registration Id" := JsonHelper.GetValueAsText(JLocation, 'node.taxRegistrationId', MaxStrLen(CompanyLocation."Tax Registration Id"));
#pragma warning restore AA0139
                CompanyLocation.Recipient := CopyStr(JsonHelper.GetValueAsText(JLocation, 'node.billingAddress.recipient', MaxStrLen(CompanyLocation.Recipient)), 1, MaxStrLen(CompanyLocation.Recipient));
                CompanyLocation."Shpfy Payment Terms Id" := CommunicationMgt.GetIdOfGId(JsonHelper.GetValueAsText(JLocation, 'node.buyerExperienceConfiguration.paymentTermsTemplate.id'));
                if IsDefaultCompanyLocation then begin
                    CompanyLocation.Default := IsDefaultCompanyLocation;
                    IsDefaultCompanyLocation := false;
                end;
                CompanyLocation.Modify(true);
            end;
            exit(true);
        end;
    end;
}