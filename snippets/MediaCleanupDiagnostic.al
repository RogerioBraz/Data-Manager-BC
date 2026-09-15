// Esqueleto de rotina de diagnóstico em AL (app própria)
var
    MediaCleanup: Codeunit "Media Cleanup";
    DetachedMedia: List of [Guid];
begin
    DetachedMedia := MediaCleanup.GetDetachedTenantMedia();
    // auditar antes de excluir: logar ID, Description, tamanho estimado
end;
