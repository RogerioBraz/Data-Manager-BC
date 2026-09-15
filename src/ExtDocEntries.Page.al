page 80501 "RBZ Ext. Doc. Entries"
{
    Caption = 'External Document Entries';
    PageType = List;
    SourceTable = "RBZ Ext. Doc. Entry";
    SourceTableView = sorting("Entry No.") order(descending);
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false; // registros nascem do Manager, nunca por digitação

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.") { ApplicationArea = All; }
                field("Company Name"; Rec."Company Name") { ApplicationArea = All; }
                field(Description; Rec.Description) { ApplicationArea = All; }
                field("Source Table No."; Rec."Source Table No.")
                {
                    ApplicationArea = All;
                    Caption = 'Origem (Tabela)';
                }
                field("Source Key"; Rec."Source Key") { ApplicationArea = All; }
                field(Status; Rec.Status) { ApplicationArea = All; StyleExpr = StatusStyleExpr; }
                field("Content Type"; Rec."Content Type") { ApplicationArea = All; }
                field("Size (KB)"; Rec."Size (KB)") { ApplicationArea = All; }
                field("SHA256 Hash"; Rec."SHA256 Hash") { ApplicationArea = All; Visible = false; }
                field("Media Id"; Rec."Media Id") { ApplicationArea = All; Visible = false; }
                field("Upload DateTime"; Rec."Upload DateTime") { ApplicationArea = All; }
                field("Uploaded By"; Rec."Uploaded By") { ApplicationArea = All; }
            }
            part(FactBox; "RBZ Ext. Doc. FactBox") { ApplicationArea = All; }
        }
    }

    actions
    {
        area(Processing)
        {
            action(OpenDocument)
            {
                ApplicationArea = All;
                Caption = 'Abrir Documento';
                Image = Document;
                Scope = Repeater;
                ToolTip = 'Baixa o conteúdo do Azure Blob via proxy do servidor BC e abre localmente.';

                trigger OnAction()
                var
                    Manager: Codeunit "RBZ Ext. Doc. Manager";
                begin
                    Manager.OpenDocument(Rec);
                end;
            }
            action(VerifyIntegrity)
            {
                ApplicationArea = All;
                Caption = 'Verificar Integridade';
                Image = CheckDuplicates;
                Scope = Repeater;
                ToolTip = 'Recalcula o SHA256 do blob e compara com o hash registrado.';

                trigger OnAction()
                var
                    Manager: Codeunit "RBZ Ext. Doc. Manager";
                begin
                    // Implementar no Manager: Download → hash → comparar com "SHA256 Hash"
                    // Retorno: Message com OK ou Error com divergência + suggest re-upload
                    Manager.VerifyIntegrity(Rec);
                end;
            }
            action(DeleteDocument)
            {
                ApplicationArea = All;
                Caption = 'Excluir Documento';
                Image = Delete;
                Scope = Repeater;
                Enabled = Rec.Status <> Rec.Status::Migrated; // só permite onde não há vínculo ativo

                trigger OnAction()
                var
                    Manager: Codeunit "RBZ Ext. Doc. Manager";
                    ConfirmQst: Label 'Excluir o documento %1 do storage externo e seu registro?', Comment = '%1 = descrição';
                begin
                    if not Confirm(ConfirmQst, false, Rec.Description) then
                        exit;
                    Manager.DeleteDocument(Rec); // deleta blob + entry; ordem: entry após blob confirmado
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Documento';
                actionref(OpenDocument_Promoted; OpenDocument) { }
                actionref(VerifyIntegrity_Promoted; VerifyIntegrity) { }
                actionref(DeleteDocument_Promoted; DeleteDocument) { }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        StatusStyleExpr := GetStatusStyle();
    end;

    local procedure GetStatusStyle(): Text
    begin
        case Rec.Status of
            Rec.Status::Migrated:
                exit('Favorable');
            Rec.Status::"Backup Only":
                exit('Standard');
            Rec.Status::"Source Removed":
                exit('Ambiguous');
        end;
    end;

    var
        StatusStyleExpr: Text;
}
