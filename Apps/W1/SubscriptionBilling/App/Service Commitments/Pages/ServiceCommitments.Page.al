namespace Microsoft.SubscriptionBilling;

using Microsoft.Finance.Dimension;

page 8064 "Service Commitments"
{
    Caption = 'Subscription Lines';
    PageType = ListPart;
    SourceTable = "Subscription Line";
    AutoSplitKey = true;
    InsertAllowed = false;
    DeleteAllowed = true;
    ModifyAllowed = true;
    ApplicationArea = All;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Package Code"; Rec."Subscription Package Code")
                {
                    Visible = false;
                    ToolTip = 'Specifies the code of the Subscription Package. If a Vendor Subscription Contract line has the same Subscription No. and Package Code as a Customer Subscription Contract line, the Customer Subscription Contract dimension value is copied to the Vendor Subscription Contract line.';
                }
                field(Template; Rec.Template)
                {
                    Visible = false;
                    ToolTip = 'Specifies the code of the Subscription Package Line Template.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies the description of the Subscription Line.';
                }
                field("Service Start Date"; Rec."Subscription Line Start Date")
                {
                    ToolTip = 'Specifies the date from which the Subscription Line is valid and will be invoiced.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Service End Date"; Rec."Subscription Line End Date")
                {
                    ToolTip = 'Specifies the date up to which the Subscription Line is valid.';
                }
                field("Planned Serv. Comm. exists"; Rec."Planned Sub. Line exists")
                {
                    ToolTip = 'Specifies if a planned Renewal exists for the Subscription Line.';
                }
                field("Next Billing Date"; Rec."Next Billing Date")
                {
                    ToolTip = 'Specifies the date of the next billing possible.';
                }
                field("Calculation Base Amount"; Rec."Calculation Base Amount")
                {
                    ToolTip = 'Specifies the base amount from which the price will be calculated.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Calculation Base %"; Rec."Calculation Base %")
                {
                    ToolTip = 'Specifies the percent at which the price of the Subscription Line will be calculated. 100% means that the price corresponds to the Base Price.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field(Price; Rec.Price)
                {
                    ToolTip = 'Specifies the price of the Subscription Line with quantity of 1 in the billing period. The price is calculated from Base Price and Base Price %.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Discount %"; Rec."Discount %")
                {
                    ToolTip = 'Specifies the percent of the discount for the Subscription Line.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Discount Amount"; Rec."Discount Amount")
                {
                    ToolTip = 'Specifies the amount of the discount for the Subscription Line.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Service Amount"; Rec.Amount)
                {
                    ToolTip = 'Specifies the amount for the Subscription Line including discount.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Unit Cost (LCY)"; Rec."Unit Cost (LCY)")
                {
                    ToolTip = 'Specifies the unit cost of the item.';
                    trigger OnValidate()
                    begin
                        Rec.UpdateServiceCommitment(Rec.FieldNo("Unit Cost (LCY)"));
                        CurrPage.Update();
                    end;
                }
                field("Calculation Base Amount (LCY)"; Rec."Calculation Base Amount (LCY)")
                {
                    ToolTip = 'Specifies the basis on which the price is calculated in client currency.';
                    Visible = false;
                }
                field("Price (LCY)"; Rec."Price (LCY)")
                {
                    ToolTip = 'Specifies the price of the Subscription Line in client currency related to quantity of 1 in the billing period. The price is calculated from Base Price and Base Price %.';
                    Visible = false;
                }
                field("Discount Amount (LCY)"; Rec."Discount Amount (LCY)")
                {
                    ToolTip = 'Specifies the discount amount in client currency that is granted on the Subscription Line.';
                    Visible = false;
                }
                field("Service Amount (LCY)"; Rec."Amount (LCY)")
                {
                    ToolTip = 'Specifies the amount in client currency for the Subscription Line including discount.';
                    Visible = false;
                }
                field("Currency Code"; Rec."Currency Code")
                {
                    ToolTip = 'Specifies the currency of amounts in the Subscription Line.';
                    Visible = false;
                }
                field("Currency Factor"; Rec."Currency Factor")
                {
                    ToolTip = 'Specifies the currency factor valid for the Subscription Line, which is used to convert amounts to the client currency.';
                    Visible = false;
                }
                field("Currency Factor Date"; Rec."Currency Factor Date")
                {
                    ToolTip = 'Specifies the date when the currency factor was last updated.';
                    Visible = false;
                }
                field("Billing Base Period"; Rec."Billing Base Period")
                {
                    ToolTip = 'Specifies for which period the Amount is valid. If you enter 1M here, a period of one month, or 12M, a period of 1 year, to which Amount refers to.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Billing Rhythm"; Rec."Billing Rhythm")
                {
                    ToolTip = 'Specifies the Date formula for Rhythm in which the Subscription Line is invoiced. Using a Dateformula rhythm can be, for example, a monthly, a quarterly or a yearly invoicing.';
                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field("Invoicing via"; Rec."Invoicing via")
                {
                    ToolTip = 'Specifies whether the Subscription Line is invoiced via a contract. Subscription Lines with invoicing via sales are not charged. Only the items are billed.';
                }
                field("Invoicing Item No."; Rec."Invoicing Item No.")
                {
                    ToolTip = 'Specifies the value of the Invoicing Item No. field.';
                    Visible = false;
                }
                field(Partner; Rec.Partner)
                {
                    ToolTip = 'Specifies whether the Subscription Line will will be calculated as a credit (Purchase Invoice) or as debit (Sales Invoice).';
                }
                field("Contract No."; Rec."Subscription Contract No.")
                {
                    ToolTip = 'Specifies in which contract the Subscription Line will be calculated.';
                    Editable = false;
                    Lookup = false;

                    trigger OnAssistEdit()
                    begin
                        ContractsGeneralMgt.OpenContractCard(Rec.Partner, Rec."Subscription Contract No.");
                    end;
                }
                field("Initial Term"; Rec."Initial Term")
                {
                    ToolTip = 'Specifies a date formula for calculating the minimum term of the Subscription Line. If the minimum term is filled and no extension term is entered, the end of Subscription Line is automatically set to the end of the initial term.';
                }
                field("Extension Term"; Rec."Extension Term")
                {
                    ToolTip = 'Specifies a date formula for automatic renewal after initial term and the rhythm of the update of "Notice possible to" and "Term Until". If the field is empty and the initial term or notice period is filled, the end of Subscription Line is automatically set to the end of the initial term or notice period.';
                }
                field("Renewal Term"; Rec."Renewal Term")
                {
                    ToolTip = 'Specifies a date formula by which the Contract Line is renewed and the end of the Contract Line is extended. It is automatically preset with the initial term of the Subscription Line and can be changed manually.';
                    Visible = false;
                }
                field("Cancellation Possible Until"; Rec."Cancellation Possible Until")
                {
                    ToolTip = 'Specifies the last date for a timely termination. The date is determined by the initial term, extension term and a notice period. An initial term of 12 months and a 3-month notice period means that the deadline for a notice of termination is after 9 months. An extension period of 12 months postpones this date by 12 months.';
                }
                field("Term Until"; Rec."Term Until")
                {
                    ToolTip = 'Specifies the earliest regular date for the end of the Subscription Line, taking into account the initial term, extension term and a notice period. An initial term of 24 months results in a fixed term of 2 years. An extension period of 12 months postpones this date by 12 months.';
                }
                field("Notice Period"; Rec."Notice Period")
                {
                    Visible = false;
                    ToolTip = 'Specifies a date formula for the lead time that a notice must have before the Subscription Line ends. The rhythm of the update of "Notice possible to" and "Term Until" is determined using the extension term. For example, with an extension period of 1M, the notice period is repeatedly postponed by one month.';
                }
                field(Discount; Rec.Discount)
                {
                    Editable = false;
                    ToolTip = 'Specifies whether the Subscription Line is used as a basis for periodic invoicing or discounts.';
                }
                field("Create Contract Deferrals"; Rec."Create Contract Deferrals")
                {
                    ToolTip = 'Specifies whether this Subscription Line should generate contract deferrals. If it is set to No, no deferrals are generated and the invoices are posted directly to profit or loss.';
                }
                field("Next Price Update"; Rec."Next Price Update")
                {
                    Visible = false;
                    Editable = not Rec."Exclude from Price Update";
                    ToolTip = 'Specifies the date of the next price update.';
                }
                field("Exclude from Price Update"; Rec."Exclude from Price Update")
                {
                    Visible = false;
                    ToolTip = 'Specifies whether this line is considered in by the Contract Price Update. Setting it to yes will exclude the line from all price updates.';
                }
                field("Period Calculation"; Rec."Period Calculation")
                {
                    Visible = false;
                    ToolTip = 'Specifies the Period Calculation, which controls how a period is determined for billing. The calculation of a month from 28.02. can extend to 27.03. (Align to Start of Month) or 30.03. (Align to End of Month).';
                }
                field("Price Binding Period"; Rec."Price Binding Period")
                {
                    Visible = false;
                    ToolTip = 'Specifies the period the price will not be changed after the price update. It sets a new "Next Price Update" in the contract line after the price update has been performed.';
                }
                field(UsageBasedBilling; Rec."Usage Based Billing")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether usage data is used as the basis for billing via contracts.';
                }
                field(sageBasedPricing; Rec."Usage Based Pricing")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the method for customer based pricing.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update();
                    end;
                }
                field(PricingUnitCostSurcharPerc; Rec."Pricing Unit Cost Surcharge %")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the surcharge in percent for the debit-side price calculation, if a EK surcharge is to be used.';
                    Editable = PricingUnitCostSurchargeEditable;
                }
                field(SupplierReferenceEntryNo; Rec."Supplier Reference Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the sequence number of the related reference.';
                }

            }
        }
    }
    actions
    {
        area(Processing)
        {
#if not CLEAN26
            group(ServiceCommitments)
            {
                Caption = 'Subscription Lines';
                Image = "Item";
                ObsoleteReason = 'This group control is removed';
                ObsoleteState = Pending;
                ObsoleteTag = '26.0';
            }
#endif
            action(NewLine)
            {
                ApplicationArea = All;
                Caption = 'New Line';
                Image = NewRow;
                Scope = Repeater;
                ToolTip = 'Creates a new entry.';

                trigger OnAction()
                var
                    ServiceCommitment: Record "Subscription Line";
                begin
                    ServiceCommitment.Copy(Rec);
                    ServiceCommitment.FilterGroup(4);
                    ServiceCommitment.NewLineForServiceObject();
                end;
            }
            action(Dimensions)
            {
                AccessByPermission = tabledata Dimension = R;
                ApplicationArea = Dimensions;
                Caption = 'Dimensions';
                Image = Dimensions;
                Scope = Repeater;
                ShortcutKey = 'Shift+Ctrl+D';
                ToolTip = 'View or edit dimensions, such as area, project, or department, that you can assign to sales and purchase documents to distribute costs and analyze transaction history.';

                trigger OnAction()
                begin
                    Rec.EditDimensionSet();
                end;
            }
            action(DisconnectfromSubscription)
            {
                ApplicationArea = All;
                Caption = 'Disconnect from Subscription';
                ToolTip = 'Disconnects the Subscription Line from the Supplier Subscription.';
                Enabled = Rec."Supplier Reference Entry No." <> 0;
                Image = DeleteQtyToHandle;
                Scope = Repeater;

                trigger OnAction()
                var
                    UsageBasedBillingMgmt: Codeunit "Usage Based Billing Mgmt.";
                begin
                    UsageBasedBillingMgmt.DisconnectServiceCommitmentFromSubscription(Rec);
                end;
            }
            action("Usage Data")
            {
                ApplicationArea = All;
                Caption = 'Usage Data';
                Image = DataEntry;
                Scope = Repeater;
                ToolTip = 'Shows the related usage data.';
                Enabled = UsageDataEnabled;

                trigger OnAction()
                var
                    UsageDataBilling: Record "Usage Data Billing";
                begin
                    UsageDataBilling.ShowForServiceCommitments(Rec.Partner, Rec."Subscription Header No.", Rec."Entry No.");
                end;
            }
            action(UsageDataBillingMetadata)
            {
                ApplicationArea = All;
                Caption = 'Usage Data Metadata';
                Image = DataEntry;
                Scope = Repeater;
                ToolTip = 'Shows the metadata related to the Subscription Line.';
                Enabled = UsageDataEnabled;

                trigger OnAction()
                begin
                    Rec.ShowUsageDataBillingMetadata();
                end;
            }
        }
    }
    trigger OnAfterGetRecord()
    begin
        Rec.CalcFields("Sub. Header Customer No.");
        PricingUnitCostSurchargeEditable := Rec."Usage Based Pricing" = Enum::"Usage Based Pricing"::"Unit Cost Surcharge";
    end;

    trigger OnAfterGetCurrRecord()
    var
        UsageDataBilling: Record "Usage Data Billing";
    begin
        UsageDataEnabled := UsageDataBilling.ExistForServiceCommitments(Rec.Partner, Rec."Subscription Header No.", Rec."Entry No.");
    end;

    var
        ContractsGeneralMgt: Codeunit "Sub. Contracts General Mgt.";
        PricingUnitCostSurchargeEditable: Boolean;
        UsageDataEnabled: Boolean;
}
