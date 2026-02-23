terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfprodbackend2026kr"
    container_name       = "tfstatekr"
    key                  = "prod.gitops.tfstate"
    use_azuread_auth     = false
    use_msi              = true
  }
}
