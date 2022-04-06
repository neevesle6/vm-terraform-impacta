terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "infraimpactarg" {
  name     = "infraimpactaterraform"
  location = "West US 2"
}

resource "azurerm_virtual_network" "infraimpactavnet" {
  name                = "aulaimpactavnet"
  location            = azurerm_resource_group.infraimpactarg.location
  resource_group_name = azurerm_resource_group.infraimpactarg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    faculdade = "Impacta"
    turma = "ES23"
  }
}
 resource "azurerm_subnet" "infraimpactasubnet" {
  name                 = "aulaimpactasubnet"
  resource_group_name  = azurerm_resource_group.infraimpactarg.name
  virtual_network_name = azurerm_virtual_network.infraimpactavnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "infraimpactaip" {
  name                = "aulaimpactaip"
  resource_group_name = azurerm_resource_group.infraimpactarg.name
  location            = azurerm_resource_group.infraimpactarg.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_security_group" "infraimpactansg" {
  name                = "aulaimpactansg"
  location            = azurerm_resource_group.infraimpactarg.location
  resource_group_name = azurerm_resource_group.infraimpactarg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface_security_group_association" "infraimpactannicsg" {
  network_interface_id      = azurerm_network_interface.infraimpactanic.id
  network_security_group_id = azurerm_network_security_group.infraimpactansg.id
}

resource "azurerm_network_interface" "infraimpactanic" {
  name                = "aulaimpactanic"
  location            = azurerm_resource_group.infraimpactarg.location
  resource_group_name = azurerm_resource_group.infraimpactarg.name

  ip_configuration {
    name                            = "aulaimpactaipnic"
    subnet_id                       = azurerm_subnet.infraimpactasubnet.id
    private_ip_address_allocation   = "Dynamic"
    public_ip_address_id            = azurerm_public_ip.infraimpactaip.id
  }
}

resource "azurerm_virtual_machine" "infraimpactavm" {
  name                  = "vm-aula"
  location              = azurerm_resource_group.infraimpactarg.location
  resource_group_name   = azurerm_resource_group.infraimpactarg.name
  network_interface_ids = [azurerm_network_interface.infraimpactanic.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  tags = {
    environment = "staging"
  }
}

data "azurerm_public_ip" "aulaimpactaip"{
    name = azurerm_public_ip.infraimpactaip.name
    resource_group_name = azurerm_resource_group.infraimpactarg.name
}

resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.aulaimpactaip.ip_address
    user = "adminUser"
    password = "admin@$%user1"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.infraimpactavm
  ]
}