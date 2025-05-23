namespace Microsoft.SubscriptionBilling;

page 8081 "Vendor Contract Deferrals"
{
    ApplicationArea = All;
    Caption = 'Vendor Subscription Contract Deferrals';
    DataCaptionExpression = GetCaption();
    PageType = List;
    Editable = false;
    SourceTable = "Vend. Sub. Contract Deferral";
    UsageCategory = History;

    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Posting Date"; Rec."Posting Date")
                {
                    ToolTip = 'Specifies the posting date of the deferral.';
                }
                field("Contract No."; Rec."Subscription Contract No.")
                {
                    ToolTip = 'Specifies the number of the related contract.';
                }
                field("Document Type"; Rec."Document Type")
                {
                    ToolTip = 'Specifies the document type used to create the deferral.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ToolTip = 'Specifies the document number used to create the deferral.';
                }
                field("Service Object Description"; Rec."Subscription Description")
                {
                    ToolTip = 'Specifies the description of the Subscription that was invoiced via the purchase line.';
                }
                field("Service Commitment Description"; Rec."Subscription Line Description")
                {
                    ToolTip = 'Specifies the description of the Subscription Line that was invoiced via the purchase line.';
                }
                field("Pay-to Vendor No."; Rec."Pay-to Vendor No.")
                {
                    ToolTip = 'Specifies the number of the Vendor (invoice recipient) for which the deferral was created.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the number of the Vendor (contractor) for which the deferral was generated.';
                }
                field("Discount Amount"; Rec."Discount Amount")
                {
                    ToolTip = 'Specifies the discount amount of the deferral.';
                }
                field("Deferral Base Amount"; Rec."Deferral Base Amount")
                {
                    ToolTip = 'Specifies the amount that is the base amount for deferral.';
                }
                field("Discount %"; Rec."Discount %")
                {
                    ToolTip = 'Specifies the percentage for the deferral discount.';
                }
                field(Amount; Rec.Amount)
                {
                    ToolTip = 'Specifies the amount of the deferral.';
                }
                field(Released; Rec.Released)
                {
                    ToolTip = 'Specifies whether the deferral has been released.';
                }
                field("Contract Type"; Rec."Subscription Contract Type")
                {
                    ToolTip = 'Specifies the Subscription Contract Type of the contract for which the deferral was created.';
                }
                field("User ID"; Rec."User ID")
                {
                    ToolTip = 'Specifies the ID of the user who generated the deferral (e.g. for use in the change log).';
                }
                field("Document Posting Date"; Rec."Document Posting Date")
                {
                    ToolTip = 'Specifies the posting date of the document used to create the deferral.';
                }
                field("Release Posting Date"; Rec."Release Posting Date")
                {
                    ToolTip = 'Specifies the posting date on which the deferral was released.';
                }
                field("Number of Days"; Rec."Number of Days")
                {
                    ToolTip = 'Specifies the number of days belonging to the deferral.';
                }
                field(Discount; Rec.Discount)
                {
                    ToolTip = 'Specifies whether the Subscription Line is used as a basis for periodic invoicing or discounts.';
                }
                field("G/L Entry No."; Rec."G/L Entry No.")
                {
                    ToolTip = 'Specifies the number of the G/L item with which the deferral was released.';
                }
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the number of the deferral that was assigned when it was created from the specified number series.';
                }
            }
        }
    }
    actions
    {
        area(navigation)
        {
            action(Dimensions)
            {
                ApplicationArea = All;
                Caption = 'Dimensions';
                Image = Dimensions;
                ShortcutKey = 'Shift+Ctrl+D';
                ToolTip = 'View or edit dimensions, such as area, project, or department, that you can assign to sales and purchase documents to distribute costs and analyze transaction history.';

                trigger OnAction()
                begin
                    Rec.ShowDimensions();
                end;
            }

        }
    }
    local procedure GetCaption(): Text
    begin
        case true of
            Rec.GetFilter("Subscription Contract No.") <> '':
                exit(Rec.FieldCaption("Subscription Contract No.") + ' ' + Rec."Subscription Contract No.");
            else
                exit('');
        end;
    end;
}