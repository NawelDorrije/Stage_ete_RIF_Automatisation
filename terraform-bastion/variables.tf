variable "os_username" {
  type    = string
  default = "nawel"
}

variable "os_password" {
  type      = string
  sensitive = true
}

variable "os_project_name" {
  type    = string
  default = "stagiaires-ete-2026"
}

variable "private_network_name" {
  type    = string
  default = "reseau-stagiaires"
}

variable "private_subnet_name" {
  type    = string
  default = "subnet-stagiaires"
}

variable "external_network_name" {
  type    = string
  default = "public"
}

variable "floating_ip_subnet_id" {
  description = "ID du subnet public autorisé pour le Bastion"
  type        = string
}

variable "bastion_name" {
  type    = string
  default = "bastion-nawel-test"
}

variable "bastion_image_name" {
  type    = string
  default = "Ubuntu-22.04"
}

variable "bastion_flavor_name" {
  type    = string
  default = "m1.small-custom"
}

variable "existing_keypair_name" {
  type    = string
  default = "Full_Stack_JS_key"
}

variable "admin_ssh_keys" {
  type      = list(string)
  sensitive = true
}

variable "allowed_admin_cidrs" {
  description = "CIDR autorisés à joindre le Bastion"
  type        = list(string)
}

variable "existing_vm_ports" {
  description = "Ports Neutron des VMs du test"
  type        = map(string)
}