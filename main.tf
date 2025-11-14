terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.40.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terrrformtest-central"
    storage_account_name = "terraformtfstate898"
    container_name       = "dockerstate"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  subscription_id = ""
  client_id       = ""
  client_secret   = ""
  tenant_id       = ""
  features {}
}

locals {
  location = var.rglocation
}

resource "azurerm_resource_group" "docker_rg" {
  name     = var.rgname
  location = local.location
}

resource "azurerm_virtual_network" "docker_vnet" {
  name                = var.network_name
  resource_group_name = azurerm_resource_group.docker_rg.name
  location            = local.location
  address_space       = [var.vnet_cidr_prefix]
}

resource "azurerm_subnet" "docker_subnet1" {
  name                 = var.network_subnet_name
  virtual_network_name = azurerm_virtual_network.docker_vnet.name
  resource_group_name  = azurerm_resource_group.docker_rg.name
  address_prefixes     = [var.subnet1_cidr_prefix[0]]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "linux-nsg"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name

  security_rule {
    name                       = "SSH"
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

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.docker_subnet1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Public IPs
resource "azurerm_public_ip" "ubuntu_ip" {
  name                = "ubuntu-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "rhel_ip" {
  name                = "rhel-public-ip"
  location            = local.location
  resource_group_name = azurerm_resource_group.docker_rg.name
  allocation_method   = "Dynamic"
}

# Network Interfaces
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

# Ubuntu VM
resource "azurerm_linux_virtual_machine" "ubuntu_vm" {
  name                = "ubuntu-vm"
  resource_group_name = azurerm_resource_group.docker_rg.name
  location            = local.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.ubuntu_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# RHEL VM
resource "azurerm_linux_virtual_machine" "rhel_vm" {
  name                = "rhel-vm"
  resource_group_name = azurerm_resource_group.docker_rg.name
  location            = local.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.rhel_nic.id]

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