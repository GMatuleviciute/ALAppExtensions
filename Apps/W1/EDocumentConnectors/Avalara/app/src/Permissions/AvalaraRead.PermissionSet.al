// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.EServices.EDocumentConnector.Avalara;

permissionset 6374 "Avalara Read"
{
    Access = Public;
    Assignable = true;
    Caption = 'Avalara E-Document Connector - Read';

    Permissions = tabledata "Connection Setup" = R;
}