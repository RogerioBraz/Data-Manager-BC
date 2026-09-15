permissionset 80500 "RBZ EXT-DOC"
{
    Assignable = true;
    Caption = 'RBZ External Documents';
    Permissions =
        tabledata "RBZ Ext. Doc. Setup" = RIMD,
        tabledata "RBZ Ext. Doc. Entry" = RIMD,
        tabledata "Tenant Media" = R,
        table "RBZ Ext. Doc. Setup" = X,
        table "RBZ Ext. Doc. Entry" = X,
        page "RBZ Ext. Doc. Setup" = X,
        page "RBZ Ext. Doc. Entries" = X,
        page "RBZ Ext. Doc. FactBox" = X,
        codeunit "RBZ Ext. Doc. Manager" = X,
        codeunit "RBZ Migration Engine" = X,
        codeunit "RBZ Storage Credentials" = X,
        codeunit "RBZ Integrity Checker" = X,
        codeunit "RBZ Job Queue Setup" = X,
        codeunit "RBZ Attachment Subscriber" = X,
        codeunit "RBZ Item Picture Adapter" = X,
        codeunit "RBZ Install" = X;
}
