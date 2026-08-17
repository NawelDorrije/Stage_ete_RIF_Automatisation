-youtput "bastion_private_ip" {
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

output "ssh_lms_openedx" {
  description = "Commande SSH vers LMS-OpenedX via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.55"
}

output "ssh_odoo_server" {
  description = "Commande SSH vers Odoo Server via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.91"
}

output "ssh_full_stack_js" {
  description = "Commande SSH vers Full-Stack-JS via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.87"
}

output "ssh_java_js" {
  description = "Commande SSH vers Java-JS via le Bastion"
  value       = "ssh -J ubuntu@${var.bastion_floating_ip} ubuntu@192.168.100.149"
}