﻿// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------
namespace Microsoft.eServices.EDocument;

using System.Utilities;
using Microsoft.eServices.EDocument.Integration;
using Microsoft.eServices.EDocument.Processing.Import;

table 6124 "E-Document Log"
{
    DataClassification = CustomerContent;
    ReplicateData = false;

    Permissions =
        tabledata "E-Doc. Data Storage" = md;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
            Caption = 'Entry No';
        }
        field(2; "E-Doc. Entry No"; Integer)
        {
            Caption = 'E-Doc. Entry No';
            TableRelation = "E-Document";
        }
        field(3; "Service Code"; Code[20])
        {
            Caption = 'Service Code';
            TableRelation = "E-Document Service";
        }
        field(4; "E-Doc. Data Storage Entry No."; Integer)
        {
            Caption = 'Data Storage';
            TableRelation = "E-Doc. Data Storage";
        }
        field(5; "E-Doc. Data Storage Size"; Integer)
        {
            Caption = 'Data Storage';
            FieldClass = FlowField;
            CalcFormula = lookup("E-Doc. Data Storage"."Data Storage Size" where("Entry No." = field("E-Doc. Data Storage Entry No.")));
        }
        field(6; Status; Enum "E-Document Service Status")
        {
            Caption = 'E-Document Status';
        }
#if not CLEANSCHEMA29
        field(7; "Service Integration"; Enum "E-Document Integration")
        {
            Caption = 'Service Integration Code';
            ObsoleteReason = 'Replaced by Service Integration V2.';
#if CLEAN26
            ObsoleteState = Removed;
            ObsoleteTag = '29.0';
#else
            ObsoleteState = Pending;
            ObsoleteTag = '26.0';
#endif
        }
#endif
        field(8; "Document Type"; Enum "E-Document Type")
        {
            Caption = 'Document Type';
            Editable = false;
        }
        field(9; "Document No."; Code[20])
        {
            Caption = 'Document No.';
            Editable = false;
        }
        field(10; "Service Integration V2"; Enum "Service Integration")
        {
            Caption = 'Service Integration';
        }
        field(11; "Document Format"; Enum "E-Document Format")
        {
            Caption = 'Document Format';
            DataClassification = SystemMetadata;
        }
        field(12; "Processing Status"; Enum "Import E-Doc. Proc. Status")
        {
            Caption = 'Final Processing Status';
            Editable = false;
        }
        field(13; "Step Undone"; Boolean)
        {
            Caption = 'Step Undone';
            Editable = false;
        }
    }

    keys
    {
        key(Key1; "Entry No.")
        {
            Clustered = true;
        }
        key(Key2; "E-Doc. Entry No")
        {
            IncludedFields = Status;
            MaintainSiftIndex = false;
        }
#if not CLEANSCHEMA29
        key(Key3; Status, "Service Code", "Document Format", "Service Integration")
        {
            Clustered = false;
            ObsoleteReason = 'Replaced by Key4.';
#if CLEAN26
            ObsoleteState = Removed;
            ObsoleteTag = '29.0';
#else
            ObsoleteState = Pending;
            ObsoleteTag = '26.0';
#endif
        }
#endif
        key(Key4; Status, "Service Code", "Document Format", "Service Integration V2")
        {
            Clustered = false;
        }
    }

    var
        EDOCLogFileTxt: Label 'E-Document_Log_%1', Locked = true;
        EDocLogEntryNoExportMsg: Label 'E-Document log entry does not contain data to export.';
        NonEmptyTempBlobErr: Label 'Temp blob is not empty.';


    trigger OnDelete()
    begin
        DeleteRelatedDataStorage(Rec."E-Doc. Data Storage Entry No.");
    end;

    local procedure DeleteRelatedDataStorage(EntryNo: Integer)
    var
        EDocDataStorage: Record "E-Doc. Data Storage";
    begin
        if EntryNo = 0 then
            exit;

        EDocDataStorage.SetRange("Entry No.", EntryNo);
        if not EDocDataStorage.IsEmpty() then
            EDocDataStorage.DeleteAll(true);
    end;

    internal procedure ExportDataStorage()
    var
        EDocDataStorage: Record "E-Doc. Data Storage";
        InStr: InStream;
        FileName: Text;
    begin
        if "E-Doc. Data Storage Entry No." = 0 then
            Error(EDocLogEntryNoExportMsg);

        EDocDataStorage.Get("E-Doc. Data Storage Entry No.");
        EDocDataStorage.CalcFields("Data Storage");
        if not EDocDataStorage."Data Storage".HasValue() then
            exit;

        FileName := StrSubstNo(EDOCLogFileTxt, "E-Doc. Entry No");
        EDocDataStorage."Data Storage".CreateInStream(InStr);

        OnBeforeExportDataStorage(Rec, FileName);

        DownloadFromStream(InStr, '', '', '', FileName);
    end;

    internal procedure GetDataStorage(var TempBlob: Codeunit "Temp Blob"): Boolean
    var
        EDocDataStorage: Record "E-Doc. Data Storage";
    begin
        if TempBlob.HasValue() then
            Error(NonEmptyTempBlobErr);
        if "E-Doc. Data Storage Entry No." = 0 then
            exit(false);
        EDocDataStorage.Get("E-Doc. Data Storage Entry No.");
        EDocDataStorage.CalcFields("Data Storage");
        if not EDocDataStorage."Data Storage".HasValue() then
            exit(false);

        TempBlob.FromRecord(EDocDataStorage, EDocDataStorage.FieldNo("Data Storage"));
        if not TempBlob.HasValue() then
            exit(false);
        exit(true);
    end;

    internal procedure CanHaveMappingLogs(): Boolean
    begin
        exit(Rec.Status in [Enum::"E-Document Service Status"::Exported, Enum::"E-Document Service Status"::Imported]);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeExportDataStorage(EDocumentLog: Record "E-Document Log"; var FileName: Text)
    begin
    end;
}