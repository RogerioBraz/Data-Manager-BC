codeunit 80503 "RBZ Abs Storage Impl" implements "RBZ IStorage Provider"
{
    var
        Setup: Record "RBZ Ext. Doc. Setup";

    procedure Initialize(SetupRec: Record "RBZ Ext. Doc. Setup")
    begin
        Setup := SetupRec;
    end;

    local procedure GetContainerClient() ContainerClient: Codeunit "Abs Container Client"
    begin
        // Assinatura Initialize(account, container, SAS) — valide contra o System App da sua versão
        ContainerClient.Initialize(Setup."Account Name", Setup."Container Name", GetSasToken());
    end;

    procedure Upload(BlobName: Text; SourceInStream: InStream; ContentType: Text; var ExternalUrl: Text)
    var
        ContainerClient: Codeunit "Abs Container Client";
        BlobClient: Codeunit "Abs Blob Client";
        HttpContent: HttpContent;
    begin
        ContainerClient := GetContainerClient();
        HttpContent.WriteFrom(SourceInStream);
        BlobClient := ContainerClient.CreateBlob(BlobName, HttpContent, ContentType);
        ExternalUrl := GetBlobUrl(BlobName);
    end;

    procedure Download(BlobName: Text; var TargetOutStream: OutStream): Boolean
    var
        ContainerClient: Codeunit "Abs Container Client";
        BlobClient: Codeunit "Abs Blob Client";
        Content: HttpContent;
        ContentInStream: InStream;
    begin
        ContainerClient := GetContainerClient();
        BlobClient := ContainerClient.GetBlob(BlobName);
        if not BlobClient.Exists() then
            exit(false);
        Content := BlobClient.GetContent();
        Content.ReadAs(ContentInStream);
        CopyStream(TargetOutStream, ContentInStream);
        exit(true);
    end;

    procedure Delete(BlobName: Text): Boolean
    begin
        exit(GetContainerClient().DeleteBlob(BlobName));
    end;

    procedure Exists(BlobName: Text): Boolean
    begin
        exit(GetContainerClient().GetBlob(BlobName).Exists());
    end;

    procedure TestConnection(): Boolean
    begin
        exit(GetContainerClient().Exists());
    end;

    local procedure GetSasToken(): Text
    var
        Credentials: Codeunit "RBZ Storage Credentials";
    begin
        exit(Credentials.GetSasToken());
    end;

    local procedure GetBlobUrl(BlobName: Text): Text
    begin
        exit(StrSubstNo('https://%1.blob.core.windows.net/%2/%3',
            Setup."Account Name", Setup."Container Name", BlobName));
    end;
}
