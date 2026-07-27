resource "openstack_networking_port_v2" "bastion" {
  name           = "${var.bastion_name}-port"
  network_id     = data.openstack_networking_network_v2.private.id
  admin_state_up = true

  security_group_ids = [
    openstack_networking_secgroup_v2.bastion.id
  ]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.private.id
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "openstack_compute_instance_v2" "bastion" {
  name      = var.bastion_name
  image_id  = data.openstack_images_image_v2.ubuntu.id
  flavor_id = data.openstack_compute_flavor_v2.bastion.id
  key_pair  = var.existing_keypair_name

  network {
    port = openstack_networking_port_v2.bastion.id
  }

  user_data = <<-CLOUDINIT
    #cloud-config
    ssh_pwauth: false
    disable_root: true

    ssh_authorized_keys:
      - ${join("\n      - ", var.admin_ssh_keys)}

    package_update: true
    packages:
      - fail2ban
      - auditd
      - unattended-upgrades

    write_files:
      - path: /etc/ssh/sshd_config.d/99-bastion.conf
        permissions: "0644"
        content: |
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          PermitRootLogin no
          PubkeyAuthentication yes
          AllowAgentForwarding no
          X11Forwarding no
          PermitTunnel no
          MaxAuthTries 3
          ClientAliveInterval 300
          ClientAliveCountMax 2

    runcmd:
      - systemctl restart ssh
      - systemctl enable --now fail2ban
      - systemctl enable --now auditd
  CLOUDINIT

  lifecycle {
    prevent_destroy = true
  }
}

# resource "openstack_networking_floatingip_v2" "bastion" {
#   pool        = var.external_network_name
#   subnet_id   = var.floating_ip_subnet_id
#   description = "Floating IP du Bastion Nawel"
#
#   lifecycle {
#     prevent_destroy = true
#   }
# }



resource "openstack_networking_floatingip_associate_v2" "bastion" {
  floating_ip = var.bastion_floating_ip
  port_id     = openstack_networking_port_v2.bastion.id
}