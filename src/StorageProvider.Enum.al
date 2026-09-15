enum 80501 "RBZ Storage Provider" implements "RBZ IStorage Provider"
{
    DefaultImplementation = "Azure Blob";
    UnknownValueImplementation = "Azure Blob";

    value(0; "Azure Blob")
    {
        Implementation = "RBZ IStorage Provider" = "RBZ Abs Storage Impl";
    }
}
