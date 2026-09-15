codeunit 80507 "RBZ Item Picture Adapter" implements "RBZ ISource Adapter"
{
    procedure Supports(SourceTableNo: Integer): Boolean
    begin
        exit(SourceTableNo = Database::Item);
    end;

    procedure DetachReference(MediaId: Guid; SourceKey: Text; var Detached: Boolean)
    var
        Item: Record Item;
    begin
        if not Item.Get(SourceKey) then exit;
        if not Item."Picture".Has(MediaId) then exit; // MediaSet
        Item."Picture".Remove(MediaId);  // valide o método no symbol da sua versão
        Item.Modify();
        Detached := true;
    end;

    procedure GetOriginCaption(): Text
    begin
        exit('Imagem de Item');
    end;
}
