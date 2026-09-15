codeunit 80505 "RBZ Migration Engine"
{
    var
        Setup: Record "RBZ Ext. Doc. Setup";
        Manager: Codeunit "RBZ Ext. Doc. Manager";
        ProcessedCount: Integer;
        MigratedKb: Integer;

    procedure RunMigrationBatch()
    var
        TenantMedia: Record "Tenant Media";
        Entry: Record "RBZ Ext. Doc. Entry";
        TempBlob: Codeunit "Temp Blob";
        ContentOut: OutStream;
        ContentIn: InStream;
        Counter: Integer;
    begin
        Setup.GetRecordOnce();
        ProcessedCount := 0;
        MigratedKb := 0;
        TenantMedia.SetFilter("Company Name", '%1|%2', '', CompanyName());

        if TenantMedia.FindSet() then
            repeat
                // Idempotência: pula mídia já processada (real ou dry run)
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
                            GetExtension(TenantMedia."Mime Type"), TenantMedia.ID);
                        DetachSourceReference(TenantMedia.ID);
                    end;
                    Counter += 1;
                end;
            until (TenantMedia.Next() = 0) or (Counter >= Setup."Batch Size");

        Message(StrSubstNo('Lote concluído: %1 registros processados (%2 KB estimados).', Counter, MigratedKb));
        // Encadeie lotes via Job Queue Entry (Object Type to Run = Codeunit)
    end;

    local procedure DetachSourceReference(MediaId: Guid)
    var
        Entry: Record "RBZ Ext. Doc. Entry";
        Adapters: List of [Interface "RBZ ISource Adapter"];
        Adapter: Interface "RBZ ISource Adapter";
        Detached: Boolean;
    begin
        // Localiza o entry recém-criado para saber a origem (tabela + chave) da mídia
        Entry.SetRange("Media Id", MediaId);
        if not Entry.FindFirst() then
            exit;

        // Sem adaptador para a origem => NADA é desanexado (mídia permanece referenciada).
        // Status Backup Only reflete isso: conteúdo em backup externo, referência intacta no BC.
        BuildAdapterList(Adapters);
        foreach Adapter in Adapters do
            if Adapter.Supports(Entry."Source Table No.") then begin
                Clear(Detached);
                Adapter.DetachReference(MediaId, Entry."Source Key", Detached);
                if Detached then begin
                    Entry.Status := Entry.Status::Migrated; // referência removida; mídia vira alvo de cleanup
                    Entry.Modify();
                    LogTelemetry('RBZ0005', StrSubstNo('Referência desanexada: %1 (%2)', Entry."Source Key", Adapter.GetOriginCaption()));
                end;
            end;
    end;

    local procedure BuildAdapterList(var Adapters: List of [Interface "RBZ ISource Adapter"])
    begin
        // Registro central de adaptadores — cada origem do inventário da Fase 1 entra aqui
        // (ex.: Item Picture, logos de Company Information, anexos de e-mail, Incoming Documents)
        Adapters.Add("RBZ Item Picture Adapter");
    end;

    local procedure LogDryRun(TenantMedia: Record "Tenant Media")
    var
        DryRunEntry: Record "RBZ Ext. Doc. Entry";
    begin
        // Fase 1: registra o que SERIA migrado, sem alterar nada no storage.
        // Entry de diagnóstico: Blob Name vazio, hash marcado 'DRYRUN'.
        DryRunEntry.Init();
        DryRunEntry."Company Name" := CopyStr(TenantMedia."Company Name", 1, 30);
        DryRunEntry."Source Table No." := 0; // origem desconhecida até o inventário
        DryRunEntry."Media Id" := TenantMedia.ID;
        DryRunEntry.Description := CopyStr(TenantMedia.Description, 1, 250);
        DryRunEntry."Content Type" := CopyStr(TenantMedia."Mime Type", 1, 100);
        DryRunEntry."Size (KB)" := TenantMedia."Size" div 1024;
        DryRunEntry."SHA256 Hash" := 'DRYRUN'; // marcação: não é hash real nem blob migrado
        DryRunEntry."Upload DateTime" := CurrentDateTime();
        DryRunEntry."Uploaded By" := CopyStr(UserId(), 1, 50);
        DryRunEntry.Status := DryRunEntry.Status::"Backup Only";
        DryRunEntry.Insert(true);

        ProcessedCount += 1;
        MigratedKb += DryRunEntry."Size (KB)";
    end;

    local procedure GetExtension(MimeType: Text): Text
    begin
        // Reaproveita o mapeamento do Manager; fallback cobre mime vazio da Tenant Media
        exit(Manager.GetExtensionFromContentType(MimeType));
    end;

    local procedure LogTelemetry(Category: Text; Message: Text)
    var
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('Category', 'RBZMigration');
        Session.LogMessage(Category, Message, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
