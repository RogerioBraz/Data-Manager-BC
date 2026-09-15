codeunit 80504 "RBZ Ext. Doc. Manager"
{
    var
        Setup: Record "RBZ Ext. Doc. Setup";

    procedure UploadDocument(SourceTableNo: Integer; SourceSystemId: Guid; SourceKey: Text;
                             Description: Text; SourceInStream: InStream; ContentType: Text;
                             FileExtension: Text): Record "RBZ Ext. Doc. Entry"
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
                Hash, Entry."Blob Name", ContentType, TempBlob.Length(), Entry.Status);
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

    local procedure GetSha256(var InStream: InStream): Text
    var
        CryptoMgt: Codeunit "Cryptography Management";
    begin
        exit(CryptoMgt.GenerateHash(InStream, "Hash Algorithm"::SHA256));
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
}
