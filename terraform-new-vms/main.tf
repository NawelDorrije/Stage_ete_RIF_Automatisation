# Réseau privé existant
data "openstack_networking_network_v2" "private" {
  name = var.private_network_name
}

# Sous-réseau privé existant
data "openstack_networking_subnet_v2" "private" {
  name = var.private_subnet_name
}

# Image existante
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

# Flavor existant
data "openstack_compute_flavor_v2" "vm" {
  name = var.flavor_name
}

# Security Group créé par le projet Terraform du Bastion
data "openstack_networking_secgroup_v2" "private_vm" {
  name = var.private_vm_security_group_name
}

# Nouvelle Key Pair OpenStack dédiée à la nouvelle VM
resource "openstack_compute_keypair_v2" "my_key" {
  name       = var.vm_keypair_name
  public_key = trimspace(var.admin_ssh_public_key)
}

# Port réseau privé de la VM
resource "openstack_networking_port_v2" "vm" {
  name           = "${var.instance_name}-port"
  network_id     = data.openstack_networking_network_v2.private.id
  admin_state_up = true

  security_group_ids = [
    data.openstack_networking_secgroup_v2.private_vm.id
  ]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.private.id
  }
}

# Nouvelle VM privée
resource "openstack_compute_instance_v2" "vm" {
  name      = var.instance_name
  image_id  = data.openstack_images_image_v2.ubuntu.id
  flavor_id = data.openstack_compute_flavor_v2.vm.id

  # Utilisation de la nouvelle Key Pair
  key_pair = openstack_compute_keypair_v2.my_key.name

  network {
    port = openstack_networking_port_v2.vm.id
  }

  user_data = <<-CLOUDINIT
    #cloud-config
    ssh_pwauth: false
    disable_root: true
    package_update: true
  CLOUDINIT

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Volume Cinder
resource "openstack_blockstorage_volume_v3" "vm" {
  name        = "volume-${var.instance_name}"
  size        = var.volume_size_gb
  description = "Volume de données de ${var.instance_name}"
}

# Attachement du volume
resource "openstack_compute_volume_attach_v2" "vm" {
  instance_id = openstack_compute_instance_v2.vm.id
  volume_id   = openstack_blockstorage_volume_v3.vm.id
}

# Aucune Floating IP n'est créée pour cette VM.
# L'accès SSH s'effectue uniquement via le Bastion.