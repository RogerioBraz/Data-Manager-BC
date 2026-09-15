enum 80502 "RBZ Ext. Doc. Status"
{
    value(0; "Backup Only") { }  // conteúdo salvo fora, referência ainda no BC
    value(1; Migrated) { }       // referência de origem removida; mídia vira alvo de cleanup
    value(2; "Source Removed") { }
}
