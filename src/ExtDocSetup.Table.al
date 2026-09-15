table 80500 "RBZ Ext. Doc. Setup"
{
    Caption = 'External Document Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10]) { }
        field(2; "Storage Provider"; Enum "RBZ Storage Provider") { }
        field(3; "Account Name"; Text[250]) { Caption = 'Storage Account Name'; }
        field(4; "Container Name"; Text[63]) { }
        field(5; Enabled; Boolean) { InitValue = false; }
        field(6; "Batch Size"; Integer) { InitValue = 500; } // registros por lote de migração
        field(7; "Dry Run"; Boolean) { InitValue = true; }   // nunca migrar sem validar antes
        field(8; "Blob Path Prefix"; Text[50]) { InitValue = 'extdocs'; }
    }
    keys { key(PK; "Primary Key") { Clustered = true; } }

    procedure GetRecordOnce()
    begin
        if Get() then exit;
        Init();
        Insert();
    end;
}
