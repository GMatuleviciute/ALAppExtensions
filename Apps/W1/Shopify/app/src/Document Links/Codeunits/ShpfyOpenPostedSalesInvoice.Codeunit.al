// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Sales.History;

codeunit 30261 "Shpfy Open PostedSalesInvoice" implements "Shpfy IOpenBCDocument"
{

    procedure OpenDocument(DocumentNo: Code[20])
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
    begin
        if SalesInvoiceHeader.Get(DocumentNo) then begin
            SalesInvoiceHeader.SetRecFilter();
            Page.Run(Page::"Posted Sales Invoice", SalesInvoiceHeader);
        end;
    end;

}