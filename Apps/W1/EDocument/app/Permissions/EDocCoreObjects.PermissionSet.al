﻿// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using Microsoft.eServices.EDocument.IO;
using Microsoft.eServices.EDocument.IO.Peppol;
using Microsoft.EServices.EDocument.OrderMatch;
using Microsoft.EServices.EDocument.OrderMatch.Copilot;
using Microsoft.eServices.EDocument.Service.Participant;
using Microsoft.eServices.EDocument.Processing.Import;
using Microsoft.eServices.EDocument.Processing.Import.Purchase;
using Microsoft.eServices.EDocument.Service;
using Microsoft.eServices.EDocument.Integration.Receive;
using Microsoft.eServices.EDocument.Integration.Action;
using Microsoft.eServices.EDocument.Format;
using Microsoft.eServices.EDocument.Integration.Send;
using Microsoft.eServices.EDocument.Integration;

permissionset 6100 "E-Doc. Core - Objects"
{
    Assignable = false;
    Access = Internal;
    Caption = 'E-Document - Objects';

    Permissions =
        table "E-Doc. Data Storage" = X,
        table "E-Document Log" = X,
        table "E-Document Integration Log" = X,
        table "E-Doc. Mapping" = X,
        table "E-Doc. Mapping Log" = X,
        table "E-Document Service" = X,
        table "E-Document Service Status" = X,
        table "E-Doc. Service Data Exch. Def." = X,
        table "E-Doc. Service Supported Type" = X,
        table "E-Doc. Order Match" = X,
        table "E-Doc. Imported Line" = X,
        table "E-Doc. PO Match Prop. Buffer" = X,
        table "Service Participant" = X,
        table "E-Doc. Import Parameters" = X,
        table "E-Document Header Mapping" = X,
        table "E-Document Line Mapping" = X,
        table "E-Document Purchase Header" = X,
        table "E-Document Purchase Line" = X,
        table "E-Documents Setup" = X,
        table "E-Document Line - Field" = X,
        table "ED Purchase Line Field Setup" = X,
        codeunit "E-Document Import Job" = X,
        codeunit "E-Doc. Integration Management" = X,
        codeunit "E-Doc. Mapping" = X,
        codeunit "E-Document Background Jobs" = X,
        codeunit "E-Document Create Jnl. Line" = X,
        codeunit "E-Document Create Purch. Doc." = X,
        codeunit "E-Document Helper" = X,
        codeunit "E-Document Processing" = X,
        codeunit "E-Document Import Helper" = X,
        codeunit "E-Document Log Helper" = X,
        codeunit "E-Document Error Helper" = X,
        codeunit "E-Document Log" = X,
        codeunit "E-Doc. Export" = X,
        codeunit "E-Document No Integration" = X,
        codeunit "E-Document Subscription" = X,
        codeunit "E-Document Update Order" = X,
        codeunit "E-Document Workflow Setup" = X,
        codeunit "E-Document Created Flow" = X,
        codeunit "E-Document Get Response" = X,
        codeunit "E-Document Workflow Processing" = X,
        codeunit "E-Doc. Import" = X,
        codeunit "E-Document Create" = X,
        codeunit "E-Document Setup" = X,
        codeunit "E-Document Install" = X,
        codeunit "E-Doc. Recurrent Batch Send" = X,
        codeunit "E-Doc. Get Basic Info" = X,
        codeunit "E-Doc. Get Complete Info" = X,
        codeunit "E-Doc. Data Exchange Impl." = X,
        codeunit "E-Doc. DED PEPPOL External" = X,
        codeunit "E-Doc. DED PEPPOL Pre-Mapping" = X,
        codeunit "E-Doc. DED PEPPOL Subscribers" = X,
        codeunit "Pre-Map Sales Cr. Memo Line" = X,
        codeunit "Pre-Map Sales Inv. Line" = X,
        codeunit "Pre-Map Service Cr. Memo Line" = X,
        codeunit "Pre-Map Service Inv. Line" = X,
        codeunit "EDoc PEPPOL BIS 3.0" = X,
        codeunit "E-Doc. Line Matching" = X,
        codeunit "E-Doc. PO AOAI Function" = X,
        codeunit "E-Doc. PO Copilot Matching" = X,
        codeunit "E-Doc. Attachment Processor" = X,
        codeunit "Service Participant" = X,
        page "E-Doc. Changes Part" = X,
        page "E-Doc. Changes Preview" = X,
        page "E-Document Activities" = X,
        page "E-Doc. Mapping Logs" = X,
        page "E-Doc. Mapping Part" = X,
        page "E-Document" = X,
        page "E-Document Logs" = X,
        page "E-Document Service" = X,
        page "E-Document Services" = X,
        page "E-Documents" = X,
        page "E-Document Service Status" = X,
        page "E-Document Integration Logs" = X,
        page "E-Doc. Service Data Exch. Sub" = X,
        page "E-Doc. Order Match" = X,
        page "E-Doc. Order Line Matching" = X,
        page "E-Doc. Imported Line Sub" = X,
        page "E-Doc. Purchase Order Sub" = X,
        page "E-Doc. Order Map. Activities" = X,
        page "E-Doc Service Supported Types" = X,
        page "E-Doc. PO Copilot Prop" = X,
        page "E-Doc. PO Match Prop. Sub" = X,
        page "E-Doc. Order Match Act." = X,
        page "Service Participants" = X,
        page "E-Doc. Create Purch Order Line" = X,
        page "E-Doc. Purchase Draft Subform" = X,
        page "E-Doc. Read. Purch. Lines" = X,
        page "E-Doc. Readable Purchase Doc." = X,
        page "E-Document Purchase Draft" = X,
        page "Inbound E-Doc. Factbox" = X,
        page "Inbound E-Documents" = X,
        page "Outbound E-Doc. Factbox" = X,
        page "Outbound E-Documents" = X,
        codeunit ActionContext = X,
        codeunit "Consent Manager Default Impl." = X,
        codeunit "Download Document" = X,
        codeunit "E-Doc Error Status" = X,
        codeunit "E-Doc In Progress Status" = X,
        codeunit "E-Doc Processed Status" = X,
        codeunit "E-Doc. Create Purchase Invoice" = X,
        codeunit "E-Doc. Providers" = X,
        codeunit "E-Document Action Runner" = X,
        codeunit "E-Document ADI Handler" = X,
        codeunit "E-Document PEPPOL Handler" = X,
        codeunit "E-Document Upgrade" = X,
        codeunit "EDoc Import PEPPOL BIS 3.0" = X,
        codeunit "Empty Integration Action" = X,
        codeunit "Get Response Runner" = X,
        codeunit "Http Message State" = X,
        codeunit "Import E-Document Process" = X,
        codeunit "Integration Action Status" = X,
        codeunit "Mark Fetched" = X,
        codeunit "Prepare Purchase E-Doc. Draft" = X,
        codeunit "Receive Documents" = X,
        codeunit ReceiveContext = X,
        codeunit "Send Runner" = X,
        codeunit SendContext = X,
        codeunit "Sent Document Approval" = X,
        codeunit "Sent Document Cancellation" = X;
}
