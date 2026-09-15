interface "RBZ ISource Adapter"
{
    procedure Supports(SourceTableNo: Integer): Boolean
    procedure DetachReference(MediaId: Guid; SourceKey: Text; var Detached: Boolean)
    procedure GetOriginCaption(): Text
}
