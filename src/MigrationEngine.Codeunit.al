codeunit 80505 "RBZ Migration Engine"
{
    var
        Setup: Record "RBZ Ext. Doc. Setup";
        ProcessedCount: Integer;
        MigratedKb: Integer;

    procedure RunMigrationBatch()
    var
        TenantMedia: Record "Tenant Media";
        Entry: Record "RBZ Ext. Doc. Entry";
        Manager: Codeunit "RBZ Ext. Doc. Manager";
        TempBlob: Codeunit "Temp Blob";
        ContentOut: OutStream;
        ContentIn: InStream;
        Counter: Integer;
    begin
        Setup.GetRecordOnce();
        TenantMedia.SetFilter("Company Name", '%1|%2', '', CompanyName());

        if TenantMedia.FindSet() then
            repeat
                // Idempotência: pula mídia já processada
                Entry.SetRange("Media Id", TenantMedia.ID);
                if Entry.IsEmpty then begin
                    TenantMedia.CalcFields(Content);
                    TenantMedia.Content.CreateInStream(ContentIn);
                    if Setup."Dry Run" then
                        LogDryRun(TenantMedia)
                    else begin
                        TempBlob.CreateOutStream(ContentOut);
                        CopyStream(ContentOut, ContentIn);
                        Manager.UploadDocument(0, TenantMedia.ID, TenantMedia."Company Name",
                            TenantMedia.Description, ContentIn, TenantMedia."Mime Type",
                            GetExtension(TenantMedia."Mime Type"));
                        DetachSourceReference(TenantMedia.ID);
                    end;
                    Counter += 1;
                end;
            until (TenantMedia.Next() = 0) or (Counter >= Setup."Batch Size");

        Message(StrSubstNo('Lote concluído: %1 registros processados.', Counter));
        // Encadeie lotes via Job Queue Entry (Object Type to Run = Codeunit)
    end;

    local procedure DetachSourceReference(MediaId: Guid)
    var
        Entry: Record "RBZ Ext. Doc. Entry";
        Adapters: List of [Interface "RBZ ISource Adapter"];
        Adapter: Interface "RBZ ISource Adapter";
        Detached: Boolean;
    begin
        // Resolva o adaptador pela origem conhecida do registro (entry recém-criado)
        // Cada adaptador limpa o campo Media/MediaSet de sua tabela de origem;
        // a mídia remanescente é então removida pelo Media Cleanup padrão (órfãos).
        // Implemente o mapeamento entry → adaptador conforme o inventário da Fase 1.
    end;

    local procedure LogDryRun(TenantMedia: Record "Tenant Media")
    begin
        // Fase 1: conte por Company/Description/Mime Type e estime o tamanho antes de agir
    end;
}
