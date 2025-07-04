// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument.Formats;
using Microsoft.eServices.EDocument;

pageextension 13915 "E-Document Service DE" extends "E-Document Service"
{
    layout
    {
#if not CLEAN27
        addafter(ImportParamenters)
        {
#pragma warning disable AS0125
            group(Export)
            {
                ObsoleteState = Pending;
                ObsoleteReason = 'Rearranging the fields.';
                ObsoleteTag = '27.0';
#else
        addlast(ExportProcessing)
        {
            group(BuyerReference)
            {
                ShowCaption = false;
#endif
                field("Buyer Reference Mandatory"; Rec."Buyer Reference Mandatory")
                {
                    ApplicationArea = All;
                }
                field("Buyer Reference"; Rec."Buyer Reference")
                {
                    ApplicationArea = All;
                }
            }
#pragma warning restore AS0125
        }
    }
}