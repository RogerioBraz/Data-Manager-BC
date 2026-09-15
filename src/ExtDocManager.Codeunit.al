codeunit 80504 "RBZ Ext. Doc. Manager"
{
    var
        Setup: Record "RBZ Ext. Doc. Setup";

    procedure UploadDocument(SourceTableNo: Integer; SourceSystemId: Guid; SourceKey: Text;
                             Description: Text; SourceInStream: InStream; ContentType: Text;
                             FileExtension: Text; MediaId: Guid): Record "RBZ Ext. Doc. Entry"
    var
        Entry: Record "RBZ Ext. Doc. Entry";
        TempBlob: Codeunit "Temp Blob";
        Provider: Interface "RBZ IStorage Provider";
        HashInStream: InStream;
        Hash: Text;
        BlobName: Text;
        ExternalUrl: Text;
        ContentOutStream: OutStream;
    begin
        Setup.GetRecordOnce();
        Setup.TestField(Enabled);

        TempBlob.CreateOutStream(ContentOutStream);
        CopyStream(ContentOutStream, SourceInStream);
        TempBlob.CreateInStream(HashInStream);
        Hash := GetSha256(HashInStream);

        // Dedupe: mesmo hash → reutiliza blob existente (economia direta de espaço)
        Entry.SetRange("SHA256 Hash", Hash);
        if Entry.FindFirst() then begin
            InsertReferenceEntry(SourceTableNo, SourceSystemId, SourceKey, Description,
                Hash, Entry."Blob Name", ContentType, TempBlob.Length(), Entry.Status, MediaId);
            exit(Entry);
        end;

        BlobName := BuildBlobName(FileExtension);
        Provider := Setup."Storage Provider";
        Provider.Initialize(Setup);
        UploadWithRetry(Provider, BlobName, TempBlob, ContentType, ExternalUrl);

        Entry.Init();
        Entry."Company Name" := CopyStr(CompanyName(), 1, 30);
        Entry."Source Table No." := SourceTableNo;
        Entry."Source System Id" := SourceSystemId;
        Entry."Source Key" := CopyStr(SourceKey, 1, 250);
        Entry."Media Id" := MediaId; // rastreabilidade p/ Tenant Media de origem
        Entry.Description := CopyStr(Description, 1, 250);
        Entry."Blob Name" := CopyStr(BlobName, 1, 250);
        Entry."Content Type" := CopyStr(ContentType, 1, 100);
        Entry."Size (KB)" := (TempBlob.Length() div 1024) + 1;
        Entry."SHA256 Hash" := Hash;
        Entry."Upload DateTime" := CurrentDateTime();
        Entry."Uploaded By" := CopyStr(UserId(), 1, 50);
        Entry.Status := Entry.Status::"Backup Only";
        Entry.Insert(true);

        LogTelemetry('RBZ0001', StrSubstNo('Upload %1 (%2 KB) hash %3', BlobName, Entry."Size (KB)", Hash));
        exit(Entry);
    end;

    local procedure UploadWithRetry(Provider: Interface "RBZ IStorage Provider"; BlobName: Text;
                                    TempBlob: Codeunit "Temp Blob"; ContentType: Text; var ExternalUrl: Text)
    var
        UploadStream: InStream;
        Attempt: Integer;
        Success: Boolean;
    begin
        // Upload HTTP não é transacional: entra no fluxo só após confirmação
        for Attempt := 1 to 3 do begin
            TempBlob.CreateInStream(UploadStream);
            if TryUpload(Provider, BlobName, UploadStream, ContentType, ExternalUrl) then begin
                Success := true;
                break;
            end;
            Sleep(1000 * Attempt); // backoff simples
        end;
        if not Success then
            Error(UploadFailedErr, BlobName);
    end;

    [TryFunction]
    local procedure TryUpload(Provider: Interface "RBZ IStorage Provider"; BlobName: Text;
                              SourceInStream: InStream; ContentType: Text; var ExternalUrl: Text)
    begin
        Provider.Upload(BlobName, SourceInStream, ContentType, ExternalUrl);
    end;

    procedure OpenDocument(var Entry: Record "RBZ Ext. Doc. Entry")
    var
        Provider: Interface "RBZ IStorage Provider";
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        FileName: Text;
    begin
        Setup.GetRecordOnce();
        Provider := Setup."Storage Provider";
        Provider.Initialize(Setup);
        TempBlob.CreateOutStream(OutStr);
        if not Provider.Download(Entry."Blob Name", OutStr) then
            Error(BlobNotFoundErr, Entry."Blob Name");
        TempBlob.CreateInStream(InStr);
        FileName := Entry.Description + GetExtensionFromContentType(Entry."Content Type");
        DownloadFromStream(InStr, '', '', '', FileName); // proxy seguro via servidor BC
    end;

    procedure GetSha256(var InStream: InStream) Hash: Text
    var
        CryptoMgt: Codeunit "Cryptography Management";
    begin
        Hash := CryptoMgt.GenerateHash(InStream, "Hash Algorithm"::SHA256);
    end;

    procedure InsertReferenceEntry(SourceTableNo: Integer; SourceSystemId: Guid; SourceKey: Text;
                                   Description: Text; Hash: Text; BlobName: Text; ContentType: Text;
                                   SizeBytes: BigInteger; Status: Enum "RBZ Ext. Doc. Status"; MediaId: Guid)
    var
        Entry: Record "RBZ Ext. Doc. Entry";
    begin
        // Entrada de referência: mesmo blob (dedupe), outra origem. Não re-uploads.
        Entry.Init();
        Entry."Company Name" := CopyStr(CompanyName(), 1, 30);
        Entry."Source Table No." := SourceTableNo;
        Entry."Source System Id" := SourceSystemId;
        Entry."Source Key" := CopyStr(SourceKey, 1, 250);
        Entry."Media Id" := MediaId;
        Entry.Description := CopyStr(Description, 1, 250);
        Entry."Blob Name" := CopyStr(BlobName, 1, 250);
        Entry."Content Type" := CopyStr(ContentType, 1, 100);
        Entry."Size (KB)" := (SizeBytes div 1024) + 1;
        Entry."SHA256 Hash" := CopyStr(Hash, 1, 64);
        Entry."Upload DateTime" := CurrentDateTime();
        Entry."Uploaded By" := CopyStr(UserId(), 1, 50);
        Entry.Status := Status;
        Entry.Insert(true);

        LogTelemetry('RBZ0002', StrSubstNo('Reference %1 -> blob %2 (dedupe)', SourceKey, BlobName));
    end;

    procedure VerifyIntegrity(var Entry: Record "RBZ Ext. Doc. Entry"): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        ContentOutStream: OutStream;
        ContentInStream: InStream;
        CurrentHash: Text;
    begin
        TempBlob.CreateOutStream(ContentOutStream);
        if not DownloadToStream(Entry."Blob Name", ContentOutStream) then begin
            Entry."Verification Error" := CopyStr(BlobNotFoundErr, 1, 250);
            Entry."Verified" := false;
            Entry.Modify();
            exit(false);
        end;

        TempBlob.CreateInStream(ContentInStream);
        CurrentHash := GetSha256(ContentInStream);

        if CurrentHash = Entry."SHA256 Hash" then begin
            Entry."Last Verified DateTime" := CurrentDateTime();
            Entry."Verification Error" := '';
            Entry."Verified" := true;
            Entry.Modify();
            Message(VerifyOkMsg, Entry."Blob Name");
            exit(true);
        end;

        Entry."Last Verified DateTime" := CurrentDateTime();
        Entry."Verification Error" := CopyStr(HashMismatchErr, 1, 250);
        Entry."Verified" := false;
        Entry.Modify();
        Error(HashMismatchErr); // divergência é incidente: interrompe com mensagem clara
    end;

    procedure DeleteDocument(var Entry: Record "RBZ Ext. Doc. Entry")
    var
        Provider: Interface "RBZ IStorage Provider";
        ReferenceCount: Integer;
    begin
        Setup.GetRecordOnce();

        // Proteção: se outras origens apontam para o mesmo blob (dedupe), só o entry é removido
        Entry.SetRange("SHA256 Hash", Entry."SHA256 Hash");
        ReferenceCount := Entry.Count();
        Entry.SetRange("SHA256 Hash");

        Provider := Setup."Storage Provider";
        Provider.Initialize(Setup);

        if ReferenceCount <= 1 then begin
            if not Provider.Delete(Entry."Blob Name") then
                Message(BlobDeleteWarnMsg, Entry."Blob Name"); // blob ausente: segue p/ remover entry
            LogTelemetry('RBZ0003', StrSubstNo('Blob %1 excluído', Entry."Blob Name"));
        end else
            LogTelemetry('RBZ0004', StrSubstNo('Entry removido; blob %1 mantido (%2 referências)', Entry."Blob Name", ReferenceCount));

        Entry.Delete(true);
    end;

    procedure DownloadToStream(BlobName: Text; var TargetOutStream: OutStream): Boolean
    var
        Provider: Interface "RBZ IStorage Provider";
    begin
        Setup.GetRecordOnce();
        Provider := Setup."Storage Provider";
        Provider.Initialize(Setup);
        exit(Provider.Download(BlobName, TargetOutStream));
    end;

    procedure GetExtensionFromContentType(ContentType: Text): Text
    var
        Ext: Text;
    begin
        // Cobertura dos mime types típicos do inventário (anexos, imagens, PDFs)
        case LowerCase(CopyStr(ContentType, 1, StrPos(LowerCase(ContentType) + ';', ';') - 1)) of
            'application/pdf':
                Ext := '.pdf';
            'image/jpeg', 'image/jpg':
                Ext := '.jpg';
            'image/png':
                Ext := '.png';
            'image/gif':
                Ext := '.gif';
            'image/bmp':
                Ext := '.bmp';
            'image/tiff':
                Ext := '.tif';
            'image/svg+xml':
                Ext := '.svg';
            'text/plain':
                Ext := '.txt';
            'text/html':
                Ext := '.html';
            'text/csv':
                Ext := '.csv';
            'application/json':
                Ext := '.json';
            'application/xml', 'text/xml':
                Ext := '.xml';
            'application/zip':
                Ext := '.zip';
            'application/msword':
                Ext := '.doc';
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
                Ext := '.docx';
            'application/vnd.ms-excel':
                Ext := '.xls';
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
                Ext := '.xlsx';
            'application/vnd.openxmlformats-officedocument.presentationml.presentation':
                Ext := '.pptx';
            else
                Ext := '.bin'; // fallback seguro: DownloadFromStream exige extensão válida
        end;
        exit(Ext);
    end;

    local procedure BuildBlobName(FileExtension: Text): Text
    var
        BlobGuid: Guid;
    begin
        BlobGuid := CreateGuid();
        exit(StrSubstNo('%1/%2/%3.%4',
            Setup."Blob Path Prefix",
            Format(Today(), 0, '<Year4>/<Month,2>'),
            DelChr(LowerCase(Format(BlobGuid)), '=', '{}'),
            FileExtension));
    end;

    local procedure LogTelemetry(Category: Text; Message: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('Category', 'RBZExtDocs');
        Session.LogMessage(Category, Message, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    var
        UploadFailedErr: Label 'Falha no upload de %1 após 3 tentativas.';
        BlobNotFoundErr: Label 'Blob %1 não encontrado no storage externo.';
        HashMismatchErr: Label 'Hash divergente — conteúdo alterado ou corrompido no storage externo.';
        VerifyOkMsg: Label 'Integridade verificada: hash SHA-256 confere para %1.';
        BlobDeleteWarnMsg: Label 'Blob %1 não encontrado no storage (já removido?). Registro removido.';
}
