codeunit 80502 "RBZ Storage Credentials"
{
    var
        SasTokenKeyLbl: Label 'RBZ-EXTDOC-SAS', Locked = true;

    procedure SetSasToken(Token: Text)
    begin
        IsolatedStorage.Set(SasTokenKeyLbl, Token, DataScope::Company);
    end;

    procedure GetSasToken(): Text
    var
        Token: Text;
    begin
        if not IsolatedStorage.Get(SasTokenKeyLbl, DataScope::Company, Token) then
            Error(SasNotDefinedErr);
        exit(Token);
    end;

    var
        SasNotDefinedErr: Label 'SAS token não configurado para esta empresa.';
}
