codeunit 80506 "RBZ Integrity Checker"
{
    var
        Setup: Record "RBZ Ext. Doc. Setup";

    // Ponto de entrada do Job Queue — sem interação, sem Message
    procedure RunIntegrityCheck()
    var
        Entry: Record "RBZ Ext. Doc. Entry";
        ProcessedCount: Integer;
        FailCount: Integer;
    begin
        Setup.GetRecordOnce();
        if not Setup.Enabled then
            exit;

        Entry.SetFilter(Status, '%1|%2', Entry.Status::"Backup Only", Entry.Status::Migrated);
        Entry.SetRange("Verified", false); // campo sugerido adiante
        Entry.SetCurrentKey("Upload DateTime"); // FIFO: mais antigos primeiro
        if not Entry.FindSet() then
            exit;

        repeat
            ProcessedCount += 1;
            if not VerifySingleEntry(Entry) then
                FailCount += 1;
            Commit(); // isola cada verificação: falha em uma não desfaz o status das demais
        until (Entry.Next() = 0) or (ProcessedCount >= GetBatchLimit());

        LogTelemetry(ProcessedCount, FailCount);
    end;

    local procedure VerifySingleEntry(var Entry: Record "RBZ Ext. Doc. Entry"): Boolean
    var
        Manager: Codeunit "RBZ Ext. Doc. Manager";
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        CurrentHash: Text;
    begin
        TempBlob.CreateOutStream(OutStr);
        if not Manager.DownloadToStream(Entry."Blob Name", OutStr) then begin
            MarkAsFailed(Entry, BlobMissingErr);
            exit(false);
        end;

        TempBlob.CreateInStream(InStr);
        CurrentHash := Manager.GetSha256(InStr);

        if CurrentHash = Entry."SHA256 Hash" then begin
            Entry."Last Verified DateTime" := CurrentDateTime();
            Entry."Verification Error" := '';
            Entry."Verified" := true;
            Entry.Modify();
            exit(true);
        end;

        MarkAsFailed(Entry, HashMismatchErr);
        exit(false);
    end;

    local procedure MarkAsFailed(var Entry: Record "RBZ Ext. Doc. Entry"; Reason: Text)
    begin
        Entry."Verification Error" := CopyStr(Reason, 1, 250);
        Entry."Verified" := false;
        Entry.Modify();
        SendAlertIfCritical(Entry);
    end;

    local procedure SendAlertIfCritical(Entry: Record "RBZ Ext. Doc. Entry")
    begin
        // Alerta: e-mail ao admin ou notificação — um blob corrompido é incidente
        // Sugestão: usar Codeunit "Email Message" + "Email" com assunto [RBZ-EXTDOC]
        // Agrupar alertas: 1 e-mail por execução com lista de falhas, não 1 por registro
    end;

    local procedure GetBatchLimit(): Integer
    begin
        // Limita por tempo de execução, não só por contagem: com 220 GB,
        // baixar blobs grandes em Job Queue tem custo de egress e duração
        exit(Setup."Batch Size");
    end;

    local procedure LogTelemetry(Processed: Integer; Failed: Integer)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions.Add('Processed', Format(Processed));
        Dimensions.Add('Failed', Format(Failed));
        Session.LogMessage('RBZ0101', 'Integrity check batch finished', Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
    end;

    var
        BlobMissingErr: Label 'Blob ausente no storage externo.';
        HashMismatchErr: Label 'Hash divergente — conteúdo alterado ou corrompido.';
}
