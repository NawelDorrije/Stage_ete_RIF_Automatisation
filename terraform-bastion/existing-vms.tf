resource "openstack_networking_port_secgroup_associate_v2" "tested_vms" {
  for_each = var.existing_vm_ports

  port_id = each.value

  security_group_ids = [
    openstack_networking_secgroup_v2.private_vms.id
  ]

  # Conserve les Security Groups existants pendant la phase de test.
  enforce = false
}

# ============================================================
# Migration progressive des VMs Haythem
# ============================================================

resource "openstack_networking_port_secgroup_associate_v2" "haythem_bastion_tdp" {
  provider = openstack.haythem

  port_id = var.haythem_bastion_port

  security_group_ids = [
    openstack_networking_secgroup_v2.haythem_from_central_bastion.id
  ]

  enforce = false
}