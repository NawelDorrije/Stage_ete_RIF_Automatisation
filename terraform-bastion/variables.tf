variable "os_username" {
  description = "Nom d'utilisateur OpenStack"
  type        = string
}

variable "os_password" {
  description = "Mot de passe OpenStack"
  type        = string
  sensitive   = true
}

variable "os_project_name" {
  description = "Nom du projet OpenStack"
  type        = string
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
  description = "Clés SSH publiques autorisées sur le Bastion"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "allowed_admin_cidrs" {
  description = "CIDR autorisés à joindre le Bastion en SSH"
  type        = list(string)
}

variable "existing_vm_ports" {
  description = "Ports Neutron des VMs utilisées pour le test Bastion"
  type        = map(string)
}

variable "bastion_floating_ip" {
  description = "Floating IP existante à associer au Bastion"
  type        = string
}