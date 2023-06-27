/*

Terraform Script to deploy the following resources:
- Resource Group
- VNet
- Subnet
- Network Security Group
- NIC
- Public IP
- VM

Output:
- Public IP VM

*/


#################
# Provider Config

provider "azurerm" {
  features {}
}


#######################
# Create resource group

resource "azurerm_resource_group" "rg" {
  name     = "demo-rg2"
  location = "West Europe"
}


###############################
# Create virtual network - VNet

resource "azurerm_virtual_network" "demo-vnet" {
  name                = "demo-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.10.0.0/16"]
}


###################
# Create the subnet

resource "azurerm_subnet" "demo-snet" {
  name                 = "demo-snet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.demo-vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}


#######################
# Create the NIC for VM

resource "azurerm_network_interface" "demo-nic" {
  depends_on = [
    azurerm_public_ip.demo-pip
  ]
  name                = "example-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo-snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.demo-pip.id
  }
}


###############
# Create the VM

resource "azurerm_windows_virtual_machine" "demo-vm" {
  name                = "demo-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B4ms"
  admin_username      = "demoadminuser"
  admin_password      = "P@$$w0rd1234!" # BAD IDEA!
  network_interface_ids = [
    azurerm_network_interface.demo-nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}


###################################
# Create the Network Security Group

resource "azurerm_network_security_group" "demo-nsg" {
  name                = "demo-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRDPInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}


#########################
# Attach NSG to demo-snet

resource "azurerm_subnet_network_security_group_association" "attach-nsg" {
  subnet_id                 = azurerm_subnet.demo-snet.id
  network_security_group_id = azurerm_network_security_group.demo-nsg.id
}


############
# Create PIP

resource "azurerm_public_ip" "demo-pip" {
  name                = "demo-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

########
# Output

output "VM-IP" {
     description = "The VM Public IP is:"
     value = azurerm_public_ip.demo-pip.ip_address
 }  