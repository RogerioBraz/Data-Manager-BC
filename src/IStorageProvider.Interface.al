interface "RBZ IStorage Provider"
{
    procedure Initialize(SetupRec: Record "RBZ Ext. Doc. Setup")
    procedure Upload(BlobName: Text; SourceInStream: InStream; ContentType: Text; var ExternalUrl: Text)
    procedure Download(BlobName: Text; var TargetOutStream: OutStream): Boolean
    procedure Delete(BlobName: Text): Boolean
    procedure Exists(BlobName: Text): Boolean
    procedure TestConnection(): Boolean
}
