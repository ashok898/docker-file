variable "rgname" {
  type = string
}

variable "rglocation" {
  type = string
  default = "Central India"
}

variable "network_name" {
  type = string
}

variable "vnet_cidr_prefix" {
  type = string
}

variable "network_subnet_name" {
  type = string
}

variable "subnet1_cidr_prefix" {
  type = list(string)
}

variable "nsg_rule1" {
  type = string
}

variable "vmname" {
  type = string
}

variable "vm_count" {
  type = number
  default = 1
}

variable "vmsize" {
  type = string
}

variable "admin_username" {
  type = string
  default = "terraformadmin"
}

variable "admin_password" {
  type = string
}
