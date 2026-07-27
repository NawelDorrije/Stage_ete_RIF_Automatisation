output "bastion_private_ip" {
  description = "Adresse IP privée du Bastion"
  value       = openstack_networking_port_v2.bastion.all_fixed_ips[0]
}

output "bastion_floating_ip" {
  description = "Floating IP associée au Bastion"
  value       = var.bastion_floating_ip
}

output "ssh_bastion" {
  description = "Commande SSH pour accéder au Bastion"
  value       = "ssh ubuntu@${var.bastion_floating_ip}"
}

output "ssh_full_stack_js" {
  description = "Commande SSH vers Full-Stack-JS via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.87"
}