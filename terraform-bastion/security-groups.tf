resource "openstack_networking_secgroup_v2" "bastion" {
  name                 = "sg-bastion-nawel-test"
  description          = "SSH public vers le Bastion uniquement"
  delete_default_rules = false
}

resource "openstack_networking_secgroup_rule_v2" "bastion_ssh" {
  for_each = toset(var.allowed_admin_cidrs)

  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = each.value
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

resource "openstack_networking_secgroup_rule_v2" "bastion_icmp_private" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "192.168.100.0/24"
  security_group_id = openstack_networking_secgroup_v2.bastion.id
}

resource "openstack_networking_secgroup_v2" "private_vms" {
  name                 = "sg-private-vms-via-bastion-test"
  description          = "SSH privé uniquement depuis le Bastion"
  delete_default_rules = false
}

resource "openstack_networking_secgroup_rule_v2" "vm_ssh_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.private_vms.id
}

resource "openstack_networking_secgroup_rule_v2" "vm_icmp_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.bastion.id
  security_group_id = openstack_networking_secgroup_v2.private_vms.id
}