output "vm_name" {
  description = "Nom de la nouvelle VM"
  value       = openstack_compute_instance_v2.vm.name
}

output "vm_private_ip" {
  description = "Adresse IP privée de la nouvelle VM"
  value       = openstack_networking_port_v2.vm.all_fixed_ips[0]
}

output "vm_keypair_name" {
  description = "Key Pair associée à la nouvelle VM"
  value       = openstack_compute_keypair_v2.my_key.name
}

output "ssh_via_bastion" {
  description = "Commande SSH vers la VM via le Bastion"
  value       = "ssh -J ${var.ssh_user}@${var.bastion_floating_ip} ${var.ssh_user}@${openstack_networking_port_v2.vm.all_fixed_ips[0]}"
}

output "volume_id" {
  description = "ID du volume Cinder"
  value       = openstack_blockstorage_volume_v3.vm.id
}

output "volume_device" {
  description = "Périphérique du volume attaché"
  value       = openstack_compute_volume_attach_v2.vm.device
}