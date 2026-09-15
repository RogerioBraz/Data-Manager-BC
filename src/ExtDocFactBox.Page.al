page 80502 "RBZ Ext. Doc. FactBox"
{
    Caption = 'Resumo de Documentos Externos';
    PageType = CardPart;
    SourceTable = "RBZ Ext. Doc. Entry";
    SourceTableTemporary = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(Summary)
            {
                ShowCaption = false;
                field(TotalDocs; TotalDocs) { Caption = 'Documentos'; ApplicationArea = All; }
                field(TotalKb; TotalKb) { Caption = 'Tamanho Total (KB)'; ApplicationArea = All; }
                field(DupesAvoided; DupesAvoided) { Caption = 'Duplicatas Evitadas'; ApplicationArea = All; }
            }
        }
    }

    // SetSource(TableNo) chamado pela página pai via evento/subscriber,
    // recalcula: COUNT, SUM("Size (KB)") e contagem de hashes repetidos
    // (dedupe) para a origem selecionada.

    var
        TotalDocs: Integer;
        TotalKb: Integer;
        DupesAvoided: Integer;
}
