// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Sales.Customer;

codeunit 30240 "Shpfy County From Json Code" implements "Shpfy ICounty From Json"
{
    Access = Internal;

    internal procedure County(JAddressObject: JsonObject): Text
    var
        Customer: Record Customer;
        JsonHelper: Codeunit "Shpfy Json Helper";
    begin
        exit(CopyStr(JsonHelper.GetValueAsText(JAddressObject, 'provinceCode').Trim(), 1, MaxStrLen(Customer.County)));
    end;
}