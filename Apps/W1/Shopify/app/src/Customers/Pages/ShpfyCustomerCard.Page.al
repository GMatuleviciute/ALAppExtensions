// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Integration.Shopify;

using Microsoft.Sales.Customer;

/// <summary>
/// Page Shpfy Customer Card (ID 30106).
/// </summary>
page 30106 "Shpfy Customer Card"
{
    Caption = 'Shopify Customer Card';
    InsertAllowed = false;
    PageType = Card;
    SourceTable = "Shpfy Customer";
    UsageCategory = None;
    AboutTitle = 'About Shopify customers';
    AboutText = 'View or edit information about your customers in Shopify. If you aren''t auto-synchronizing customers, you can do that manually here. For even more details, open the [Customer Card](?page=21 "Opens the Customer Card").';
    PromotedActionCategories = 'New,Process,Related,Customer';

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';

                field(Id; Rec.Id)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique identifier for the customer in Shopify.';
                    Visible = false;
                }
                field(FirstName; Rec."First Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer''s first name.';
                }
                field(LastName; Rec."Last Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer''s last name.';
                }
                field(EMail; Rec.Email)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique email address of the customer. Attempting to assign the same e-mail address to multiple customers returns an error.';
                }
                field(Phone; Rec."Phone No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer''s telephone number.';
                }
                field(AcceptsMarketing; Rec."Accepts Marketing")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the customer consented to receive email updates from the shop.';
                }
                field(State; Rec.State)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the state of a customer''s account with a shop. The default value is disabled. Valid values are: disabled, invited, enabled and declined.';
                }
                field(VeriefiedEmail; Rec."Verified Email")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the customer has verified their e-mail address.';
                }
                field(Note; Rec.GetNote())
                {
                    ApplicationArea = All;
                    Caption = 'Note';
                    ToolTip = 'Specifies a note about the customer in Shopify.';
                }
            }

            group(Mapping)
            {
                Caption = 'Mapping';
                Editable = false;

                field(CustomerSystemId; Rec."Customer SystemId")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique identifier for the customer in D365BC.';
                    Visible = false;
                }
                field(CustomerNo; CustomerNo)
                {
                    ApplicationArea = All;
                    AssistEdit = true;
                    Caption = 'Customer No.';
                    TableRelation = Customer;
                    ToolTip = 'Specifies the mapped customer number.';

                    trigger OnValidate()
                    begin
                        if CustomerNo <> '' then begin
                            Customer.Get(CustomerNo);
                            Rec."Customer SystemId" := Customer.SystemId;
                            GetMappedCustomer();
                        end;
                    end;

                    trigger OnAssistEdit()
                    var
                        CustomerList: Page "Customer List";
                    begin
                        CustomerList.LookupMode := true;
                        CustomerList.SetRecord(Customer);
                        if CustomerList.RunModal() = Action::LookupOK then begin
                            CustomerList.GetRecord(Customer);
                            Rec."Customer SystemId" := Customer.SystemId;
                            CustomerNo := Customer."No.";
                            Rec.Modify();
                        end;
                    end;
                }
                field(Name; Customer."Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer''s name.';
                }
                field(Name2; Customer."Name 2")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies an additional part of the name.';
                }
                field(Address; Customer.Address)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the customer''s address.';
                }
            }

            part(AddressList; "Shpfy Customer Adresses")
            {
                ApplicationArea = all;
                Caption = '';
                SubPageLink = "Customer Id" = field(Id);
            }
        }
        area(FactBoxes)
        {
            part(CustomerTags; "Shpfy Tag Factbox")
            {
                ApplicationArea = All;
                SubPageLink = "Parent Table No." = const(30105), "Parent Id" = field(Id);
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(CustomerCard)
            {
                ApplicationArea = All;
                Caption = 'Customer Card';
                Image = Customer;
                Promoted = true;
                PromotedOnly = true;
                PromotedCategory = Category4;
                ToolTip = 'View or edit detailed information about the customer.';

                trigger OnAction()
                var
                    Customer: Record Customer;
                begin
                    if Customer.GetBySystemId(Rec."Customer SystemId") then begin
                        Customer.SetRecFilter();
                        Page.Run(Page::"Customer Card", Customer);
                    end;
                end;
            }

            action(ShopifyOrders)
            {
                ApplicationArea = All;
                Caption = 'Shopify Orders';
                Image = OrderList;
                Promoted = true;
                PromotedOnly = true;
                PromotedCategory = Category4;
                RunObject = Page "Shpfy Orders";
                RunPageLink = "Customer Id" = field(Id);
                ToolTip = 'View a list of Shopify orders for the customer.';
            }
            action(Metafields)
            {
                ApplicationArea = All;
                Caption = 'Metafields';
                Image = PriceAdjustment;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                PromotedOnly = true;
                ToolTip = 'Add metafields to a customer. This can be used for adding custom data fields to customers in Shopify.';

                trigger OnAction()
                var
                    Shop: Record "Shpfy Shop";
                    Metafields: Page "Shpfy Metafields";
                begin
                    Shop.SetRange("Shop Id", Rec."Shop Id");
                    Shop.FindFirst();
                    Metafields.RunForResource(Database::"Shpfy Customer", Rec.Id, Shop.Code);
                end;
            }
        }

    }

    var
        Customer: Record Customer;
        CustomerNo: Code[20];

    trigger OnAfterGetCurrRecord()
    begin
        GetMappedCustomer();
    end;

    /// <summary> 
    /// Get Mapped Customer.
    /// </summary>
    local procedure GetMappedCustomer()
    begin
        if IsNullGuid(Rec."Customer SystemId") then begin
            Clear(Customer);
            Clear(CustomerNo);
        end else
            if Customer.GetBySystemId(Rec."Customer SystemId") then
                CustomerNo := Customer."No."
            else begin
                Clear(Customer);
                Clear(CustomerNo);
            end;
    end;
}
