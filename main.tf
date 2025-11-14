terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.40.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
   subscription_id = "6dc04dce-61ca-4a0a-a008-d5a5e06b8b1a"
   client_id       = "262befed-62f1-4ae3-9f89-3d15b75b4bc0"
   client_secret = "REDACTED"
   tenant_id       = "000cbff9-0cf0-4826-88f4-e8d0f8d13de3"
   features {}
}

locals {
  location = "eastus2"
}

resource "azurerm_resource_group" "docker_rg" {
  name     = var.rgname
  location = local.location
}

resource "azurerm_virtual_network" "docker_vnet" {
  name                = var.network_name
  resource_group_name = azurerm_resource_group.docker_rg.name
  location            = local.location
  address_space       = var.vnet_cidr_prefix
}

resource "azurerm_subnet" "docker_subnet1" {
  name                 = var.network_subnet_name
  virtual_network_name = azurerm_virtual_network.docker_vnet.name
  resource_group_name  = azurerm_resource_group.docker_rg.name
  address_prefixes     = var.subnet1_cidr_prefix
}

resource "azurerm_network_security_group" "nsg" {
  name                = "linux-nsg"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  security_rule {
    name                       = var.nsg_rule1
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.docker_subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "ubuntu_ip" {
  name                = "ubuntu-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "rhel_ip" {
  name                = "rhel-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "ubuntu_nic" {
  name                = "ubuntu-nic"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  ip_configuration {
    name                          = "ubuntu-ipconfig"
    subnet_id                     = azurerm_subnet.docker_subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu_ip.id
  }
}

resource "azurerm_network_interface" "rhel_nic" {
  name                = "rhel-nic"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  ip_configuration {
    name                          = "rhel-ipconfig"
    subnet_id                     = azurerm_subnet.docker_subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.rhel_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "ubuntu_vm" {
  name                = "ubuntu-vm"
  resource_group_name = azurerm_resource_group.docker_rg.name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.ubuntu_nic.id]
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18_04-lts-gen2"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "rhel_vm" {
  name                = "rhel-vm"
  resource_group_name = azurerm_resource_group.docker_rg.name
  location            = local.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.rhel_nic.id]
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8_4"
    version   = "latest"
  }
}
