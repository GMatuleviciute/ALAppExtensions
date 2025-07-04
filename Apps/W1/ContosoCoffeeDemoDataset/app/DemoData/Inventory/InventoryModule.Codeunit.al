// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.DemoData.Inventory;

using Microsoft.DemoTool;

codeunit 5680 "Inventory Module" implements "Contoso Demo Data Module"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    procedure RunConfigurationPage()
    var
        ContosoDemoTool: Codeunit "Contoso Demo Tool";
    begin
        Message(ContosoDemoTool.GetNoConfiguirationMsg());
    end;

    procedure GetDependencies() Dependencies: List of [enum "Contoso Demo Data Module"]
    begin
        Dependencies.Add(Enum::"Contoso Demo Data Module"::Foundation);
        Dependencies.Add(Enum::"Contoso Demo Data Module"::Finance);
    end;

    procedure CreateSetupData()
    begin
        Codeunit.Run(Codeunit::"Create Inventory Posting Group");
        Codeunit.Run(Codeunit::"Create Inventory Setup");
        Codeunit.Run(Codeunit::"Create Item Journal Template");
        Codeunit.Run(Codeunit::"Create Requisition Wksh. Name");
        Codeunit.Run(Codeunit::"Create Order Promising Setup");
        Codeunit.Run(Codeunit::"Create Inventory Posting Setup");
        Codeunit.Run(Codeunit::"Create Assembly Setup");
        Codeunit.Run(Codeunit::"Create Territory");
    end;

    procedure CreateMasterData()
    var
        CreateInvPostingSetup: Codeunit "Create Inventory Posting Setup";
    begin
        Codeunit.Run(Codeunit::"Create Location");
        CreateInvPostingSetup.UpdateInventoryPostingSetup();
        Codeunit.Run(Codeunit::"Create Manufacturer");
        Codeunit.Run(Codeunit::"Create Item Category");
        Codeunit.Run(Codeunit::"Create Item Template");
        Codeunit.Run(Codeunit::"Create Item");
        Codeunit.Run(Codeunit::"Create Item Attribute");
        Codeunit.Run(Codeunit::"Create Item Charge");
        Codeunit.Run(Codeunit::"Create Item Tracking Code");
        Codeunit.Run(Codeunit::"Create BOM Component");
        Codeunit.Run(Codeunit::"Create Purchasing");
    end;

    procedure CreateTransactionalData()
    begin
        Codeunit.Run(Codeunit::"Create Item Reference");
        Codeunit.Run(Codeunit::"Create Nonstock Item");
        Codeunit.Run(Codeunit::"Create Transfer Orders");
    end;

    procedure CreateHistoricalData()
    begin
        exit;
    end;
}
