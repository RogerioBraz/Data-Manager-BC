codeunit 80508 "RBZ Attachment Subscriber"
{
    [EventSubscriber(ObjectType::Page, Page::"Document Attachments", 
        'OnAfterCopyFieldsFromDocumentAttachment', '', false, false)]
    local procedure OnAfterCopyFields(var DocumentAttachment: Record "Document Attachment")
    begin
        // Gancho de interceptação: quando Enabled no setup, o stream do anexo
        // é redirecionado ao RBZ Ext. Doc. Manager antes da gravação padrão,
        // gravando no BC apenas o metadado (ou nem isso, conforme política).
        // Avaliar alternativa: assinar eventos do codeunit de anexos em vez da página
        // (mais estável entre atualizações — página muda, codeunit de domínio não).
    end;
}
