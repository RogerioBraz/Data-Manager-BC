codeunit 80510 "RBZ Install" implements "Per Database Upgrade"
{
    // No BC moderno prefira a interface "Per Database Upgrade" (install codeunit)
    // registrada via subtype no objeto de instalação da sua versão-alvo
    trigger OnInstallAppPerDatabase()
    begin
        EnsureSetupRecord();
        EnsureJobQueueEntry();
    end;

    local procedure EnsureSetupRecord()
    var
        Setup: Record "RBZ Ext. Doc. Setup";
    begin
        Setup.GetRecordOnce();
    end;
}
