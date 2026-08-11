terraform {
  cloud {
    organization = "rif-stagiaires"

    workspaces {
      name = "Nawel-Bastion-Test"
    }
  }

  required_version = ">= 1.7.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

provider "openstack" {
  user_name           = var.os_username
  password            = var.os_password
  tenant_name         = var.os_project_name
  user_domain_name    = var.os_user_domain_name
  project_domain_name = var.os_project_domain_name

  auth_url = "http://127.0.0.1:5000/v3"
  region   = "RegionOne"

  endpoint_overrides = {
    identity = "http://127.0.0.1:5000/v3/"
    compute  = "http://127.0.0.1:8774/v2.1/"
    network  = "http://127.0.0.1:9696/v2.0/"
    image    = "http://127.0.0.1:19292/v2/"
    volumev3 = "http://127.0.0.1:8776/v3/"
  }
}

variable "os_user_domain_name" {
  description = "Domaine OpenStack de l'utilisateur"
  type        = string
  default     = "Default"
}

variable "os_project_domain_name" {
  description = "Domaine OpenStack du projet"
  type        = string
  default     = "Default"
}



provider "openstack" {
  alias = "haythem"

  user_name           = var.os_username
  password            = var.os_password
  tenant_name         = var.haythem_project_name
  user_domain_name    = var.os_user_domain_name
  project_domain_name = var.os_project_domain_name

  auth_url = "http://127.0.0.1:5000/v3"
  region   = "RegionOne"

  endpoint_overrides = {
    identity = "http://127.0.0.1:5000/v3/"
    compute  = "http://127.0.0.1:8774/v2.1/"
    network  = "http://127.0.0.1:9696/v2.0/"
    image    = "http://127.0.0.1:19292/v2/"
    volumev3 = "http://127.0.0.1:8776/v3/"
  }
}