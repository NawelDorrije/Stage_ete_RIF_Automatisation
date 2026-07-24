output "bastion_private_ip" {
  value       = openstack_networking_port_v2.bastion.all_fixed_ips[0]
  description = "IP privée du Bastion"
}

output "bastion_floating_ip" {
  value       = openstack_networking_floatingip_v2.bastion.address
  description = "Floating IP du Bastion"
}

output "ssh_bastion" {
  value = "ssh ubuntu@${openstack_networking_floatingip_v2.bastion.address}"
}

output "ssh_full_stack_js" {
  value = "ssh -J ubuntu@${openstack_networking_floatingip_v2.bastion.address} ubuntu@192.168.100.87"
}

output "ssh_lms_openedx" {
  value = "ssh -J ubuntu@${openstack_networking_floatingip_v2.bastion.address} ubuntu@192.168.100.55"
}

