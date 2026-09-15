table 80501 "RBZ Ext. Doc. Entry"
{
    Caption = 'External Document Entry';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; BigInteger) { AutoIncrement = true; }
        field(2; "Company Name"; Code[30]) { Caption = 'Company'; }
        field(3; "Source Table No."; Integer) { Caption = 'Source Table'; }
        field(4; "Source System Id"; Guid) { }       // SystemId do registro de origem
        field(5; "Source Key"; Text[250]) { }        // PK legível p/ auditoria (ex.: Item No.)
        field(6; "Media Id"; Guid) { }               // rastreabilidade p/ Tenant Media de origem
        field(10; Description; Text[250]) { }
        field(11; "Blob Name"; Text[250]) { }
        field(12; "Content Type"; Text[100]) { }
        field(13; "Size (KB)"; Integer) { }
        field(14; "SHA256 Hash"; Text[64]) { }       // integridade + dedupe
        field(15; "Upload DateTime"; DateTime) { }
        field(16; "Uploaded By"; Code[50]) { }
        field(17; Status; Enum "RBZ Ext. Doc. Status") { }
        field(18; Verified; Boolean) { Caption = 'Verificado'; }
        field(19; "Last Verified DateTime"; DateTime) { Caption = 'Última Verificação'; }
        field(20; "Verification Error"; Text[250]) { Caption = 'Erro de Verificação'; }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(Hash; "SHA256 Hash") { }      // índice de dedupe
        key(Media; "Media Id") { }        // idempotência da migração
        key(Upload; "Upload DateTime") { } // FIFO da verificação de integridade
    }
}
