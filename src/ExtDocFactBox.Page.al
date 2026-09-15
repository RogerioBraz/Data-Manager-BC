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
                field(TotalDocs; TotalDocs)
                {
                    Caption = 'Documentos';
                    ApplicationArea = All;
                    ToolTip = 'Quantidade de documentos externos da origem selecionada.';
                }
                field(TotalKb; TotalKb)
                {
                    Caption = 'Tamanho Total (KB)';
                    ApplicationArea = All;
                    ToolTip = 'Soma do tamanho dos documentos da origem selecionada.';
                }
                field(DupesAvoided; DupesAvoided)
                {
                    Caption = 'Duplicatas Evitadas';
                    ApplicationArea = All;
                    ToolTip = 'Referências que reutilizam blob de outro documento (dedupe por hash).';
                }
            }
        }
    }

    var
        TotalDocs: Integer;
        TotalKb: Integer;
        DupesAvoided: Integer;
        SeenHashes: List of [Text];

    procedure SetSource(SourceTableNo: Integer)
    var
        Entry: Record "RBZ Ext. Doc. Entry";
        Hash: Text;
    begin
        // Agregações por origem em uma passada: COUNT, SUM(Size) e dedupe por hash.
        // SeenHashes controla hashes já contabilizados (dedupe).
        TotalDocs := 0;
        TotalKb := 0;
        DupesAvoided := 0;
        Clear(SeenHashes);

        Entry.SetRange("Source Table No.", SourceTableNo);
        if Entry.FindSet() then
            repeat
                TotalDocs += 1;
                TotalKb += Entry."Size (KB)";
                Hash := Entry."SHA256 Hash";
                if SeenHashes.Contains(Hash) then
                    DupesAvoided += 1
                else
                    SeenHashes.Add(Hash);
            until Entry.Next() = 0;
    end;
}
