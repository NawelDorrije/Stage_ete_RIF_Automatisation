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
  user_name   = var.os_username
  password    = var.os_password
  tenant_name = var.os_project_name
  auth_url    = "http://localhost:5000/v3"
  region      = "RegionOne"


  endpoint_overrides = {
    identity = "http://localhost:5000/v3/"
    compute  = "http://localhost:8774/v2.1/"
    network  = "http://localhost:9696/v2.0/"
    image    = "http://localhost:9292/v2/"
    volumev3 = "http://localhost:8776/v3/"
  }
}