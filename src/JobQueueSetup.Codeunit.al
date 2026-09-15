codeunit 80509 "RBZ Job Queue Setup"
{
    procedure EnsureJobQueueEntry()
    var
        JobQueueEntry: Record "Job Queue Entry";
        Setup: Record "RBZ Ext. Doc. Setup";
    begin
        Setup.GetRecordOnce();

        // Idempotente: reutiliza a entrada existente em vez de criar duplicata
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"RBZ Integrity Checker");
        if JobQueueEntry.FindFirst() then
            exit;

        JobQueueEntry.Init();
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"RBZ Integrity Checker";
        JobQueueEntry."Recurring Job" := true;
        JobQueueEntry."Run in User Session" := false; // roda no contexto do NAS, sem usuário
        JobQueueEntry."Earliest Start Date/Time" := CreateDateTime(Today(), 020000T); // 02:00 — janela de baixo movimento
        Evaluate(JobQueueEntry."Minutes Between Runs", '1440'); // diário
        JobQueueEntry.Description := 'RBZ - Verificação de integridade de documentos externos';
        JobQueueEntry.Insert(true);
    end;
}
