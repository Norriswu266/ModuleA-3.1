terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# -----------------------------
# Identity: Microsoft Entra ID Integration
# -----------------------------
resource "azurerm_resource_group" "alz_identity" {
  name     = "rg-alz-identity"
  location = "japaneast"

  tags = local.common_tags
}

resource "azurerm_user_assigned_identity" "vm_identity" {
  name                = "uai-vm-managed"
  location            = azurerm_resource_group.alz_identity.location
  resource_group_name = azurerm_resource_group.alz_identity.name

  tags = local.common_tags
}

# -----------------------------
# Networking: Azure Topology
# -----------------------------
resource "azurerm_resource_group" "alz_network" {
  name     = "rg-alz-network"
  location = "japaneast"

  tags = local.common_tags
}

# Hub-VNet
resource "azurerm_virtual_network" "hub_vnet" {
  name                = "vnet-hub-jpe"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.alz_network.location
  resource_group_name = azurerm_resource_group.alz_network.name
  tags                = local.common_tags
}

# Spoke-VNet
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = "vnet-spoke-app-jpe"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.alz_network.location
  resource_group_name = azurerm_resource_group.alz_network.name
  tags                = local.common_tags
}

# Hub-Spoke Peering
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "hub-to-spoke"
  resource_group_name       = azurerm_resource_group.alz_network.name
  virtual_network_name      = azurerm_virtual_network.hub_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnet.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "spoke-to-hub"
  resource_group_name       = azurerm_resource_group.alz_network.name
  virtual_network_name      = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id
  use_remote_gateways       = true
}

# VPN Gateway (Hybrid Connectivity)
resource "azurerm_public_ip" "vpn_pip" {
  name                = "pip-vpn-gateway"
  location            = azurerm_resource_group.alz_network.location
  resource_group_name = azurerm_resource_group.alz_network.name
  allocation_method   = "Dynamic"
  tags                = local.common_tags
}

resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  name                = "vpngw-hub-jpe"
  location            = azurerm_resource_group.alz_network.location
  resource_group_name = azurerm_resource_group.alz_network.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  enable_bgp          = false
  sku                 = "VpnGw1"
  ip_configurations {
    name                          = "vpngw-ipcfg"
    public_ip_address_id          = azurerm_public_ip.vpn_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_virtual_network.hub_vnet.subnets[0].id
  }
  tags = local.common_tags
}

# -----------------------------
# Resource Organization: Naming & Tagging
# -----------------------------
locals {
  common_tags = {
    Environment = "Production"
    Owner       = "CloudTeam"
    CostCenter  = "IT-001"
    ManagedBy   = "Terraform"
  }
}

# 範例命名規則 (標準化 Resource 命名)
resource "azurerm_resource_group" "alz_app" {
  name     = "rg-alz-app-prod"
  location = "japaneast"
  tags     = local.common_tags
}
