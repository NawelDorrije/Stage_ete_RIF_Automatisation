variable "os_username" {
  description = "Nom d'utilisateur OpenStack"
  type        = string
  default     = "admin"
}

variable "os_password" {
  description = "Mot de passe OpenStack fourni avec TF_VAR_os_password"
  type        = string
  sensitive   = true
}

variable "os_project_name" {
  description = "Nom du projet OpenStack"
  type        = string
  default     = "admin"
}

variable "os_user_domain_name" {
  type    = string
  default = "Default"
}

variable "os_project_domain_name" {
  type    = string
  default = "Default"
}

variable "private_network_name" {
  type    = string
  default = "reseau-stagiaires"
}

variable "private_subnet_name" {
  type    = string
  default = "subnet-stagiaires"
}

variable "private_vm_security_group_name" {
  description = "Security Group autorisant SSH depuis le Bastion"
  type        = string
  default     = "sg-private-vms-via-bastion-test"
}

variable "instance_name" {
  type    = string
  default = "new-vm-via-bastion"
}

variable "image_name" {
  type    = string
  default = "Ubuntu-22.04"
}

variable "flavor_name" {
  type    = string
  default = "m1.small-custom"
}

variable "vm_keypair_name" {
  description = "Nom de la nouvelle Key Pair OpenStack"
  type        = string
  default     = "New_VM_key"
}

variable "admin_ssh_public_key" {
  description = "Clé publique utilisée pour créer la nouvelle Key Pair"
  type        = string
  sensitive   = true
}

variable "volume_size_gb" {
  description = "Taille du volume Cinder en Go"
  type        = number
  default     = 10

  validation {
    condition     = var.volume_size_gb >= 1
    error_message = "La taille du volume doit être supérieure ou égale à 1 Go."
  }
}

variable "bastion_floating_ip" {
  description = "Floating IP du Bastion"
  type        = string
  default     = "188.40.148.152"
}

variable "ssh_user" {
  description = "Utilisateur SSH Ubuntu"
  type        = string
  default     = "ubuntu"
}

