// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.Finance.VAT.Setup;

using System.Security.AccessControl;

permissionsetextension 10580 "D365 BASIC ISV - Reports GB" extends "D365 BASIC ISV"
{
    IncludedPermissionSets = "Reports GB - Objects";
}