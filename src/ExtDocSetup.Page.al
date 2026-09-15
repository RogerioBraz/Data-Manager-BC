page 80500 "RBZ Ext. Doc. Setup" 
{
    Caption = 'External Document Setup';
    PageType = Card;
    SourceTable = "RBZ Ext. Doc. Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Geral';
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Ativa a externalização de documentos para storage externo.';
                }
                field("Storage Provider"; Rec."Storage Provider")
                {
                    ApplicationArea = All;
                }
                field("Blob Path Prefix"; Rec."Blob Path Prefix")
                {
                    ApplicationArea = All;
                    ToolTip = 'Prefixo do caminho dos blobs no container (ex.: extdocs).';
                }
            }
            group(AzureBlob)
            {
                Caption = 'Azure Blob Storage';
                Visible = IsAzureBlob;

                field("Account Name"; Rec."Account Name")
                {
                    ApplicationArea = All;
                }
                field("Container Name"; Rec."Container Name")
                {
                    ApplicationArea = All;
                }
                field(SasTokenInput; SasTokenInput)
                {
                    ApplicationArea = All;
                    Caption = 'SAS Token';
                    ExtendedDatatype = Masked; // mascara o valor na UI
                    ToolTip = 'SAS token com permissão de leitura/escrita no container. Armazenado em IsolatedStorage, não no banco.';

                    trigger OnValidate()
                    begin
                        // Persiste somente ao confirmar; nunca grava em tabela
                    end;
                }
            }
            group(Migration)
            {
                Caption = 'Migração';
                field("Dry Run"; Rec."Dry Run")
                {
                    ApplicationArea = All;
                    ToolTip = 'Quando ativo, o motor de migração apenas registra o que faria, sem alterar nada.';
                }
                field("Batch Size"; Rec."Batch Size")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Testar Conexão';
                Image = Link;
                ToolTip = 'Valida credenciais e existência do container.';

                trigger OnAction()
                var
                    Provider: Interface "RBZ IStorage Provider";
                begin
                    Rec.GetRecordOnce();
                    Rec.TestField("Account Name");
                    Rec.TestField("Container Name");
                    SaveSasToken(); // aplica o token digitado antes de testar
                    Provider := Rec."Storage Provider";
                    Provider.Initialize(Rec);
                    if Provider.TestConnection() then
                        Message(ConnOkMsg)
                    else
                        Error(ConnFailErr);
                end;
            }
            action(RunMigration)
            {
                ApplicationArea = All;
                Caption = 'Executar Lote de Migração';
                Image = ExportDatabase;
                Enabled = Rec.Enabled;

                trigger OnAction()
                var
                    MigrationEngine: Codeunit "RBZ Migration Engine";
                    ConfirmQst: Label 'Executar lote de migração em modo %1?', Comment = '%1 = Dry Run ou Execução';
                begin
                    if Rec."Dry Run" then
                        Message(DryRunInfoMsg) // informa que nada será alterado
                    else
                        if not Confirm(ConfirmQst, false, 'EXECUÇÃO REAL') then
                            exit;
                    MigrationEngine.RunMigrationBatch();
                end;
            }
            action(ScheduleIntegrityCheck)
            {
                ApplicationArea = All;
                Caption = 'Agendar Verificação de Integridade';
                Image = Calendar;
                ToolTip = 'Cria (ou reutiliza) a entrada de Job Queue que roda a verificação de integridade diariamente às 02:00.';

                trigger OnAction()
                var
                    JobQueueSetup: Codeunit "RBZ Job Queue Setup";
                begin
                    JobQueueSetup.EnsureJobQueueEntry();
                    Message(QueuedMsg);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetRecordOnce();
        UpdateVisibility();
    end;

    trigger OnAfterGetRecord()
    begin
        UpdateVisibility();
        // Carrega apenas indicativo de presença, nunca o valor
        SasTokenInput := '';
    end;

    local procedure UpdateVisibility()
    begin
        IsAzureBlob := Rec."Storage Provider" = Rec."Storage Provider"::"Azure Blob";
    end;

    local procedure SaveSasToken()
    var
        Credentials: Codeunit "RBZ Storage Credentials";
    begin
        if SasTokenInput = '' then
            exit;
        Credentials.SetSasToken(SasTokenInput);
        Clear(SasTokenInput);
        Message(TokenSavedMsg);
    end;

    var
        SasTokenInput: Text;
        IsAzureBlob: Boolean;
        ConnOkMsg: Label 'Conexão validada com sucesso.';
        ConnFailErr: Label 'Falha na conexão. Verifique account, container e SAS token.';
        DryRunInfoMsg: Label 'Modo Dry Run ativo: nenhum dado será alterado, apenas registro do que seria processado.';
        TokenSavedMsg: Label 'SAS token armazenado com segurança (IsolatedStorage).';
        QueuedMsg: Label 'Verificação de integridade agendada na Job Queue (diária, 02:00).';
}
