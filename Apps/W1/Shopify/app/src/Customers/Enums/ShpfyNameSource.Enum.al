// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

/// <summary>
/// Enum Shpfy Name Source (ID 30108) implements Interface Shpfy ICustomer Name.
/// </summary>
enum 30108 "Shpfy Name Source" implements "Shpfy ICustomer Name"
{
    Caption = 'Shopify Name Source';
    Extensible = false;
    DefaultImplementation = "Shpfy ICustomer Name" = "Shpfy Name is Empty";

    value(0; CompanyName)
    {
        Caption = 'Company Name';
        Implementation = "Shpfy ICustomer Name" = "Shpfy Name is CompanyName";
    }
    value(1; FirstAndLastName)
    {
        Caption = 'First Name and Last Name';
        Implementation = "Shpfy ICustomer Name" = "Shpfy Name is First. LastName";
    }
    value(2; LastAndFirstName)
    {
        Caption = 'Last Name and First Name';
        Implementation = "Shpfy ICustomer Name" = "Shpfy Name is Last. FirstName";
    }
    value(3; None)
    {
        Caption = 'None';
        Implementation = "Shpfy ICustomer Name" = "Shpfy Name is Empty";
    }
}
