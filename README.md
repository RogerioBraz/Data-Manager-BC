# RBZ External Document Storage — Data Manager BC

Extensão AL para **Dynamics 365 Business Central (SaaS)** que externaliza o conteúdo de
`Tenant Media` (anexos, imagens, PDFs) para **Azure Blob Storage**, mantendo no banco apenas
metadados — com dedupe por SHA-256, migração do histórico em lotes e verificação periódica
de integridade via Job Queue.

> **Contexto:** ambiente com crescimento anômalo de capacidade — `Tenant Media` com
> 4.655.306 registros e 231.555.936 KB (~220,8 GiB). Projeto gerado a partir do estudo
> documentado no Adapta ("Data_Manager_BC.docx").

## Arquitetura

| Camada | Objetos | Papel |
| --- | --- | --- |
| Configuração | Setup, Credentials, Job Queue Setup, Install | Parâmetros, segredo isolado (IsolatedStorage), agendamento idempotente |
| Contrato | `RBZ IStorage Provider` + enum + Abs impl | Abstração de storage, testável com fake |
| Domínio | `RBZ Ext. Doc. Entry`, `RBZ Ext. Doc. Manager` | Metadados, dedupe por hash, upload/download |
| Migração | `RBZ Migration Engine`, `RBZ ISource Adapter` | Backup do histórico + desanexação de referências |
| Operação | `RBZ Integrity Checker` (Job Queue) | Verificação periódica de integridade + alertas |
| UX | Setup page, Entries page, FactBox | Operação segura com visibilidade de status |

```
[Rota de entrada: upload novo]        [Rota de migração: histórico]
        │                                      │
        ▼                                      ▼
  RBZ Ext. Doc. Manager  ◄────────── RBZ Migration Engine
        │                                      │
        ▼                                      ▼
  RBZ IStorage Provider (interface) ──► RBZ Abs Storage Impl
        │
        ▼
  Azure Blob (conteúdo)  +  RBZ Ext. Doc. Entry (metadados/hash/dedupe no BC)
```

## Estrutura do repositório

```
app.json                            # manifest (faixa 80500–80599, System App dependency)
src/
  ExtDocSetup.Table.al              # table 80500 — setup (provider, container, batch, dry run)
  ExtDocEntry.Table.al              # table 80501 — metadados (hash, blob name, status, verificação)
  ExtDocStatus.Enum.al              # enum 80502 — Backup Only / Migrated / Source Removed
  StorageProvider.Enum.al           # enum 80501 — implementa RBZ IStorage Provider
  IStorageProvider.Interface.al     # contrato de storage
  ISourceAdapter.Interface.al       # contrato de desanexação de referências
  StorageCredentials.Codeunit.al    # SAS token em IsolatedStorage (escopo Company)
  AbsStorageImpl.Codeunit.al        # implementação Azure Blob (Abs Container Client)
  ExtDocManager.Codeunit.al         # upload/download com dedupe SHA-256 e retry
  MigrationEngine.Codeunit.al       # migração da Tenant Media em lotes (idempotente)
  ItemPictureAdapter.Codeunit.al    # adaptador de origem: Picture da tabela Item
  IntegrityChecker.Codeunit.al      # batch noturno de verificação de hash (Job Queue)
  JobQueueSetup.Codeunit.al         # agendamento idempotente na Job Queue
  AttachmentSubscriber.Codeunit.al  # gancho (fase 2) no fluxo de Document Attachments
  Install.Codeunit.al               # install codeunit (cria setup + agenda Job Queue)
  ExtDocSetup.Page.al               # página Card de setup (SAS mascarado, ações)
  ExtDocEntries.Page.al             # página List de entries (abrir/verificar/excluir)
  ExtDocFactBox.Page.al             # FactBox de resumo por origem
  ExtDoc.PermissionSet.al           # permissionset 80500 RBZ EXT-DOC
snippets/
  MediaCleanupDiagnostic.al         # esqueleto de diagnóstico de mídia órfã (Fase 2)
```

## Fluxo operacional

1. **Setup** (página *External Document Setup*): informar account/container, colar SAS token
   (mascarado; vai para IsolatedStorage, nunca para tabela), `Testar Conexão`.
2. **Dry Run ativo por padrão** — a migração só grava após desativar explicitamente.
3. **Migração em lotes** (`Batch Size`, default 500): percorre `Tenant Media`, faz upload do
   conteúdo para o Blob, registra entry e delega a desanexação ao adaptador de origem.
4. **Media Cleanup padrão** coleta os órfãos resultantes — a deleção **nunca** é direta na
   `Tenant Media`.
5. **Verificação de integridade** diária às 02:00 (Job Queue): recalcula SHA-256 do blob e
   compara com o hash registrado; falhas ficam em `Verification Error`.

## O que está como esboço (validar antes do build)

- [ ] **Assinaturas do módulo ABS** (`Abs Container Client` / `Abs Blob Client`) contra o
      symbol file da versão-alvo — único ponto dependente de versão.
- [ ] `RBZ Migration Engine.DetachSourceReference` — implementar o mapeamento
      entry → adaptador conforme o inventário da Fase 1.
- [ ] `RBZ Migration Engine.LogDryRun` / `GetExtension` — corpos vazios no documento de origem.
- [ ] `RBZ Ext. Doc. Manager`: expor `GetSha256` como procedure pública e implementar
      `InsertReferenceEntry`, `VerifyIntegrity`, `DeleteDocument` e
      `GetExtensionFromContentType` (citados pelas páginas/batch).
- [ ] `RBZ Item Picture Adapter` — validar método `MediaSet.Remove` no symbol da versão.
- [ ] Eventos do **Document Attachment** na versão-alvo (nomes mudaram entre 20→24).
- [ ] Adaptadores adicionais de origem (logos, anexos de e-mail, Incoming Documents)
      conforme inventário.
- [ ] Alerta de falha de integridade agrupado por execução (e-mail ao admin).

## Referências

- [Managing Capacity — Microsoft Learn](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/administration/tenant-admin-center-capacity)
- [Codeunit Media Cleanup — Microsoft Learn](https://learn.microsoft.com/en-us/dynamics365/business-central/application/system-application/codeunit/system.dataadministration.media-cleanup)
- [Data Archive Extension — Microsoft Learn](https://learn.microsoft.com/en-us/dynamics365/business-central/admin-archive-data)
- [Waldo — Cleaning up Media Orphans](https://waldo.be/2024/07/12/cleaning-up-media-orphans-with-the-data-administration-tool-in-business-central/)
- [Demiliani — Media orphans](https://demiliani.com/2023/12/20/dynamics-365-business-central-remember-to-delete-the-media-orphans)
