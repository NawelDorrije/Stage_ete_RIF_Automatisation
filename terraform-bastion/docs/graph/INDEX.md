# Graph Index — Master Node Registry & Edge Table

Canonical registry of every node and relationship in the `terraform-bastion` knowledge graph.
Node **definitions** live in each node's *Home Document* (no duplication).
Machine-readable export: [`graph.json`](graph.json).

---

## 1. Master Node Registry

### 1.1 Actors

| ID | Name | Type | Layer | Home Document |
|---|---|---|---|---|
| `ACTOR-ADMINS` | Administrators / Developers | Actor | Operational | [ssh-workflows.md](ssh-workflows.md) |

### 1.2 Infrastructure Components

| ID | Name | Type | Layer | Home Document |
|---|---|---|---|---|
| `INFRA-OPENSTACK` | OpenStack Cloud (local, RegionOne) | Infrastructure Component | Infrastructure | [networking.md](networking.md) |
| `INFRA-OPENSTACK-ENDPOINTS` | Localhost Endpoint Overrides | Infrastructure Component | Networking | [networking.md](networking.md) |
| `INFRA-TFCLOUD` | Terraform Cloud Backend (`rif-stagiaires` / `Nawel-Bastion-Test`) | Infrastructure Component | Terraform | [terraform-platform.md](terraform-platform.md) |
| `INFRA-BASTION-PORT` | Neutron Port `bastion-nawel-test-port` | Infrastructure Component | Networking | [bastion-host.md](bastion-host.md) |
| `INFRA-FIP` | Pre-existing Floating IP | Infrastructure Component | Networking | [bastion-host.md](bastion-host.md) |
| `INFRA-FIP-ASSOC` | Floating IP ↔ Port Association | Infrastructure Component | Networking | [bastion-host.md](bastion-host.md) |
| `INFRA-KEYPAIR` | Keypair `Full_Stack_JS_key` | Infrastructure Component | Security | [bastion-host.md](bastion-host.md) |
| `INFRA-IMAGE` | Glance Image `Ubuntu-22.04` | Infrastructure Component | Infrastructure | [bastion-host.md](bastion-host.md) |
| `INFRA-FLAVOR` | Flavor `m1.small-custom` | Infrastructure Component | Infrastructure | [bastion-host.md](bastion-host.md) |
| `INFRA-CLOUDINIT` | Bastion Cloud-Init Hardening | Infrastructure Component | Security | [bastion-host.md](bastion-host.md) |
| `INFRA-ANSIBLE` | Ansible Playbook `bastion-hardening.yml` | Infrastructure Component | Security | [bastion-host.md](bastion-host.md) |

### 1.3 Virtual Machines

| ID | Name | Private IP | Type | Layer | Home Document |
|---|---|---|---|---|---|
| `VM-BASTION` | `bastion-nawel-test` | (from port) | VM | Infrastructure + Security | [bastion-host.md](bastion-host.md) |
| `VM-FULL-STACK-JS` | Full-Stack-JS | `192.168.100.87` | VM | Infrastructure | [vm-integration.md](vm-integration.md) |
| `VM-LMS-OPENEDX` | LMS-OpenedX | `192.168.100.55` | VM | Infrastructure | [vm-integration.md](vm-integration.md) |
| `VM-ODOO-SERVER` | Odoo Server | `192.168.100.91` | VM | Infrastructure | [vm-integration.md](vm-integration.md) |
| `VM-JAVA-JS` | Java-JS | `192.168.100.149` | VM | Infrastructure | [vm-integration.md](vm-integration.md) |
| `VM-MERN-FRONTEND` | MERN Frontend (future) | TBD | VM | Infrastructure | [future-roadmap.md](future-roadmap.md) |
| `VM-MERN-BACKEND` | MERN Backend (future) | TBD | VM | Infrastructure | [future-roadmap.md](future-roadmap.md) |
| `VM-MERN-MONGODB` | MERN MongoDB (future) | TBD | VM | Infrastructure | [future-roadmap.md](future-roadmap.md) |

### 1.4 Networks

| ID | Name | Type | Layer | Home Document |
|---|---|---|---|---|
| `NET-PRIVATE` | Private Network `reseau-stagiaires` | Network | Networking | [networking.md](networking.md) |
| `NET-PRIVATE-SUBNET` | Subnet `subnet-stagiaires` (`192.168.100.0/24`) | Network | Networking | [networking.md](networking.md) |
| `NET-EXTERNAL` | External Network `public` | Network | Networking | [networking.md](networking.md) |

### 1.5 Security Groups

| ID | Name | Type | Layer | Home Document |
|---|---|---|---|---|
| `SG-BASTION` | `sg-bastion-nawel-test` | Security Group | Security | [security-model.md](security-model.md) |
| `SG-RULE-BASTION-SSH` | SSH/22 from allowed admin CIDRs | Security Group | Security | [security-model.md](security-model.md) |
| `SG-RULE-BASTION-ICMP` | ICMP from `192.168.100.0/24` | Security Group | Security | [security-model.md](security-model.md) |
| `SG-PRIVATE-VMS` | `sg-private-vms-via-bastion-test` | Security Group | Security | [security-model.md](security-model.md) |
| `SG-RULE-VM-SSH-FROM-BASTION` | SSH/22 from bastion SG | Security Group | Security | [security-model.md](security-model.md) |
| `SG-RULE-VM-ICMP-FROM-BASTION` | ICMP from bastion SG | Security Group | Security | [security-model.md](security-model.md) |
| `SG-ASSOC-PILOT-VMS` | Port↔SG association on existing VMs | Security Group | Security | [vm-integration.md](vm-integration.md) |

### 1.6 Terraform Module, Variables, Outputs, Data Sources

| ID | Name | Type | Layer | Home Document |
|---|---|---|---|---|
| `TFMOD-ROOT` | Root module `terraform-bastion` | Terraform Module | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-OS-USERNAME` | `os_username` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-OS-PASSWORD` | `os_password` (sensitive) | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-OS-PROJECT-NAME` | `os_project_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-OS-USER-DOMAIN-NAME` | `os_user_domain_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-OS-PROJECT-DOMAIN-NAME` | `os_project_domain_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-PRIVATE-NETWORK-NAME` | `private_network_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-PRIVATE-SUBNET-NAME` | `private_subnet_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-EXTERNAL-NETWORK-NAME` | `external_network_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-FLOATING-IP-SUBNET-ID` | `floating_ip_subnet_id` (**orphan**) | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-BASTION-NAME` | `bastion_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-BASTION-IMAGE-NAME` | `bastion_image_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-BASTION-FLAVOR-NAME` | `bastion_flavor_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-EXISTING-KEYPAIR-NAME` | `existing_keypair_name` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-ADMIN-SSH-KEYS` | `admin_ssh_keys` (sensitive) | Terraform Variable | Terraform + Security | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-ALLOWED-ADMIN-CIDR` | `allowed_admin_cidrs` | Terraform Variable | Terraform + Security | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-EXISTING-VM-PORTS` | `existing_vm_ports` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFVAR-BASTION-FLOATING-IP` | `bastion_floating_ip` | Terraform Variable | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFOUT-BASTION-PRIVATE-IP` | `bastion_private_ip` | Terraform Output | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFOUT-BASTION-FLOATING-IP` | `bastion_floating_ip` | Terraform Output | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFOUT-SSH-BASTION` | `ssh_bastion` | Terraform Output | Terraform + Operational | [terraform-platform.md](terraform-platform.md) |
| `TFOUT-SSH-LMS-OPENEDX` | `ssh_lms_openedx` | Terraform Output | Terraform + Operational | [terraform-platform.md](terraform-platform.md) |
| `TFOUT-SSH-ODOO-SERVER` | `ssh_odoo_server` | Terraform Output | Terraform + Operational | [terraform-platform.md](terraform-platform.md) |
| `TFOUT-SSH-FULL-STACK-JS` | `ssh_full_stack_js` | Terraform Output | Terraform + Operational | [terraform-platform.md](terraform-platform.md) |
| `TFOUT-SSH-JAVA-JS` | `ssh_java_js` | Terraform Output | Terraform + Operational | [terraform-platform.md](terraform-platform.md) |
| `TFDATA-PRIVATE-NETWORK` | `data.openstack_networking_network_v2.private` | Terraform Data Source | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFDATA-PRIVATE-SUBNET` | `data.openstack_networking_subnet_v2.private` | Terraform Data Source | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFDATA-EXTERNAL-NETWORK` | `data.openstack_networking_network_v2.external` | Terraform Data Source | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFDATA-UBUNTU-IMAGE` | `data.openstack_images_image_v2.ubuntu` | Terraform Data Source | Terraform | [terraform-platform.md](terraform-platform.md) |
| `TFDATA-BASTION-FLAVOR` | `data.openstack_compute_flavor_v2.bastion` | Terraform Data Source | Terraform | [terraform-platform.md](terraform-platform.md) |

### 1.7 Deployment Steps

| ID | Name | Type | Layer | Home Document |
|---|---|---|---|---|
| `DEPLOY-INIT` | `terraform init` | Deployment Step | Terraform | [terraform-platform.md](terraform-platform.md) |
| `DEPLOY-PLAN` | `terraform plan` | Deployment Step | Terraform | [terraform-platform.md](terraform-platform.md) |
| `DEPLOY-APPLY` | `terraform apply` | Deployment Step | Terraform | [terraform-platform.md](terraform-platform.md) |
| `DEPLOY-ROLLBACK` | Rollback via git revert + apply | Deployment Step | Terraform + Operational | [operations.md](operations.md) |

### 1.8 Decisions (details in [decisions.md](decisions.md))

| ID | Decision | Implements |
|---|---|---|
| `DEC-001` | Reuse a pre-existing Floating IP; Terraform must not create one | `PRIN-NON-DESTRUCTIVE-TESTING` |
| `DEC-002` | `prevent_destroy` on bastion instance and port | `PRIN-SINGLE-ENTRY` |
| `DEC-003` | `ignore_changes = [user_data]`; post-boot changes go through Ansible | `PRIN-IAC` |
| `DEC-004` | `enforce = false` on pilot SG association (keep pre-existing SGs) | `PRIN-NON-DESTRUCTIVE-TESTING` |
| `DEC-005` | Pilot rollout order: Full-Stack-JS + LMS-OpenedX → Odoo + Java-JS → MERN | `PRIN-NON-DESTRUCTIVE-TESTING` |
| `DEC-006` | ProxyJump only; agent forwarding disabled on the bastion | `PRIN-LEAST-PRIVILEGE` |
| `DEC-007` | Single public entry point; internal VMs are SSH-private | `PRIN-SINGLE-ENTRY` |
| `DEC-008` | SG-to-SG referencing (`remote_group_id`) instead of CIDRs for VM SSH | `PRIN-LEAST-PRIVILEGE` |
| `DEC-009` | Terraform Cloud remote backend (`rif-stagiaires`/`Nawel-Bastion-Test`) | `PRIN-IAC` |
| `DEC-010` | Reuse existing keypair `Full_Stack_JS_key` | — |
| `DEC-011` | Dual hardening path: cloud-init (boot) + Ansible (steady state) | `PRIN-IAC` |
| `DEC-012` | Hardcoded localhost `endpoint_overrides` in the provider | — |

### 1.9 Design Principles (details in [decisions.md](decisions.md))

| ID | Principle |
|---|---|
| `PRIN-SINGLE-ENTRY` | One controlled, auditable SSH entry point into the private network |
| `PRIN-MIN-EXPOSURE` | Minimize public attack surface |
| `PRIN-LEAST-PRIVILEGE` | Grant the smallest network/credential scope possible |
| `PRIN-IAC` | All infrastructure change is code-reviewed and applied through Terraform/Ansible |
| `PRIN-NON-DESTRUCTIVE-TESTING` | Never break pre-existing manually-created infrastructure during migration |

### 1.10 Operational Procedures (details in [operations.md](operations.md))

| ID | Procedure |
|---|---|
| `OP-ADD-VM` | Add a new VM to the private network |
| `OP-ATTACH-TO-BASTION` | Attach an existing VM to the bastion security model |
| `OP-RETRIEVE-PORT-ID` | Retrieve a Neutron Port ID (Horizon or CLI) |
| `OP-ADD-SSH-KEY` | Add an SSH public key to the bastion |
| `OP-VERIFY-ACCESS` | Verify SSH/ICMP access end to end |
| `OP-REMOVE-VM` | Remove a VM from bastion control |
| `OP-CHANGE-ADMIN-CIDR` | Change which admin IPs may reach the bastion |
| `OP-ROLLBACK` | Roll back a Terraform change |
| `OP-RUN-ANSIBLE` | Re-apply bastion hardening with Ansible |

### 1.11 Known Issues (details in home documents)

| ID | Issue | Home Document |
|---|---|---|
| `ISSUE-USERDATA-DRIFT` | `user_data` ignored after first boot; cloud-init edits (incl. `admin_ssh_keys`) never re-apply | [bastion-host.md](bastion-host.md) |
| `ISSUE-SHARED-KEYPAIR` | Single shared keypair `Full_Stack_JS_key` reused across VMs | [bastion-host.md](bastion-host.md) |
| `ISSUE-LOCALHOST-ENDPOINTS` | Provider endpoints point to `127.0.0.1`; runs require local cloud or port-forward | [networking.md](networking.md) |
| `ISSUE-DNS` | Active branch `fix/dns-terraform` indicates unresolved DNS work | [networking.md](networking.md) |
| `ISSUE-MANUAL-PORT-ID` | Neutron Port IDs are retrieved manually (Horizon) and pasted into tfvars | [vm-integration.md](vm-integration.md) |
| `ISSUE-HARDCODED-IPS` | SSH outputs hardcode `192.168.100.x` addresses | [terraform-platform.md](terraform-platform.md) |
| `ISSUE-ORPHAN-FIP-SUBNET-VAR` | `floating_ip_subnet_id` is required but unused by active code (only referenced in commented-out resource) | [terraform-platform.md](terraform-platform.md) |
| `ISSUE-TFVARS-EXAMPLE-INCOMPLETE` | `terraform.tfvars.example` omits `os_username`, `os_password`, `os_project_name`, `bastion_floating_ip` | [terraform-platform.md](terraform-platform.md) |
| `ISSUE-LOCKFILE-GITIGNORE` | `.gitignore` line for `.terraform.lock.hcl` has a leading space → pattern ineffective, file is tracked (currently intentional but fragile) | [terraform-platform.md](terraform-platform.md) |

### 1.12 Validations (details in [operations.md](operations.md) + feature docs)

| ID | Validation | Validates |
|---|---|---|
| `VAL-FMT` | `terraform fmt -check` | `TFMOD-ROOT` |
| `VAL-VALIDATE` | `terraform validate` | `TFMOD-ROOT` |
| `VAL-PLAN` | `terraform plan` review | `TFMOD-ROOT` |
| `VAL-APPLY` | `terraform apply` success | deployed graph |
| `VAL-SSH-BASTION` | SSH to bastion via FIP | `VM-BASTION`, `SG-BASTION`, `INFRA-FIP` |
| `VAL-SSH-JUMP` | SSH through bastion to each VM | `SSH-PROXYJUMP`, `SG-PRIVATE-VMS` |
| `VAL-ICMP-PRIVATE` | ping bastion ↔ VMs on `192.168.100.0/24` | `SG-RULE-BASTION-ICMP`, `SG-RULE-VM-ICMP-FROM-BASTION` |
| `VAL-SG-AUDIT` | OpenStack CLI audit of SG rules/ports | `SG-BASTION`, `SG-PRIVATE-VMS`, `SG-ASSOC-PILOT-VMS` |
| `VAL-HARDENING` | fail2ban/auditd/sshd config checks | `INFRA-CLOUDINIT`, `INFRA-ANSIBLE` |

### 1.13 SSH Workflows (details in [ssh-workflows.md](ssh-workflows.md))

| ID | Workflow |
|---|---|
| `SSH-DIRECT-BASTION` | `ssh ubuntu@<floating-ip>` |
| `SSH-PROXYJUMP` | `ssh -J ubuntu@<floating-ip> ubuntu@<vm-private-ip>` |
| `SSH-CONFIG` | Persistent `~/.ssh/config` Host aliases |
| `SSH-SCP-VIA-JUMP` | File transfer through the bastion |

### 1.14 Future Work (details in [future-roadmap.md](future-roadmap.md))

| ID | Future Node | Depends On |
|---|---|---|
| `RP-NGINX` | Reverse proxy on the bastion (NGINX/Traefik) | `VM-BASTION` |
| `FW-REVERSE-PROXY` | Central HTTP(S) entry for hosted apps | `VM-BASTION` |
| `FW-HTTPS` | TLS certificates (Let's Encrypt) | `RP-NGINX`, `FW-DOMAIN-DNS` |
| `FW-DOMAIN-DNS` | Domain names for services | `FW-DNS-FIX` |
| `FW-DNS-FIX` | Complete DNS work of branch `fix/dns-terraform` | `NET-PRIVATE` |
| `FW-PROMETHEUS` | Metrics collection | all `VM-*` |
| `FW-GRAFANA` | Dashboards | `FW-PROMETHEUS` |
| `FW-VAULT` | Secrets management | `TFMOD-ROOT` |
| `FW-CICD` | CI/CD pipeline for Terraform/Ansible | `INFRA-TFCLOUD` |
| `FW-ENFORCE-SG` | Switch pilot association to `enforce = true` / fully managed SGs | `SG-ASSOC-PILOT-VMS` |
| `FW-MERN-ONBOARDING` | Attach MERN stack VMs to bastion model | `VM-MERN-*`, `SG-ASSOC-PILOT-VMS` |
| `FW-PORT-AUTODISCOVERY` | Replace manual Port IDs with data-source lookups | `ISSUE-MANUAL-PORT-ID` |
| `FW-INVENTORY-AUTOMATION` | Generate Ansible inventory from Terraform outputs | `INFRA-ANSIBLE`, `TFOUT-*` |

---

## 2. Master Edge Table

Predicates: `DEPENDS_ON` `USES` `EXPOSES` `CONNECTS_TO` `PROTECTS` `GENERATES`
`CONFIGURES` `VALIDATES` `IMPLEMENTS` `REPLACES` `IS_ACCESSED_VIA` `PART_OF`
`RELATED_TO` `SUPERSEDES`

| Edge | Subject | Predicate | Object | Evidence |
|---|---|---|---|---|
| E001 | `NET-PRIVATE-SUBNET` | `PART_OF` | `NET-PRIVATE` | `data.tf` |
| E002 | `INFRA-BASTION-PORT` | `CONNECTS_TO` | `NET-PRIVATE` | `bastion.tf` (port.network_id) |
| E003 | `INFRA-BASTION-PORT` | `USES` | `NET-PRIVATE-SUBNET` | `bastion.tf` (fixed_ip) |
| E004 | `VM-BASTION` | `USES` | `INFRA-BASTION-PORT` | `bastion.tf` (network.port) |
| E005 | `VM-BASTION` | `CONNECTS_TO` | `NET-PRIVATE` | `bastion.tf` |
| E006 | `INFRA-FIP-ASSOC` | `CONNECTS_TO` | `INFRA-BASTION-PORT` | `bastion.tf` (floatingip_associate) |
| E007 | `INFRA-FIP-ASSOC` | `USES` | `INFRA-FIP` | `bastion.tf` |
| E008 | `VM-BASTION` | `IS_ACCESSED_VIA` | `INFRA-FIP` | `outputs.tf` |
| E009 | `INFRA-FIP` | `PART_OF` | `NET-EXTERNAL` | `variables.tf`, tfvars example |
| E010 | `NET-EXTERNAL` | `CONNECTS_TO` | `NET-PRIVATE` | FIP→port path (`bastion.tf`) |
| E011 | `VM-BASTION` | `USES` | `INFRA-IMAGE` | `bastion.tf` (image_id) |
| E012 | `VM-BASTION` | `USES` | `INFRA-FLAVOR` | `bastion.tf` (flavor_id) |
| E013 | `VM-BASTION` | `USES` | `INFRA-KEYPAIR` | `bastion.tf` (key_pair) |
| E014 | `INFRA-CLOUDINIT` | `CONFIGURES` | `VM-BASTION` | `bastion.tf` (user_data) |
| E015 | `INFRA-ANSIBLE` | `CONFIGURES` | `VM-BASTION` | `ansible/bastion-hardening.yml` |
| E016 | `INFRA-ANSIBLE` | `REPLACES` | `INFRA-CLOUDINIT` | post-boot changes (`DEC-003`) |
| E017 | `VM-BASTION` | `EXPOSES` | SSH/22 to `TFVAR-ALLOWED-ADMIN-CIDR` | `security-groups.tf` |
| E018 | `ACTOR-ADMINS` | `CONNECTS_TO` | `VM-BASTION` | `outputs.tf` (`ssh_bastion`) |
| E019 | `ACTOR-ADMINS` | `CONNECTS_TO` | `VM-FULL-STACK-JS` | via `SSH-PROXYJUMP` |
| E020 | `ACTOR-ADMINS` | `CONNECTS_TO` | `VM-LMS-OPENEDX` | via `SSH-PROXYJUMP` |
| E021 | `ACTOR-ADMINS` | `CONNECTS_TO` | `VM-ODOO-SERVER` | via `SSH-PROXYJUMP` |
| E022 | `ACTOR-ADMINS` | `CONNECTS_TO` | `VM-JAVA-JS` | via `SSH-PROXYJUMP` |
| E023 | `SSH-DIRECT-BASTION` | `IS_ACCESSED_VIA` | `INFRA-FIP` | `outputs.tf` |
| E024 | `SSH-PROXYJUMP` | `USES` | `VM-BASTION` | `outputs.tf` (`ssh -J`) |
| E025 | `SSH-PROXYJUMP` | `CONNECTS_TO` | `VM-LMS-OPENEDX` | `outputs.tf` |
| E026 | `SSH-PROXYJUMP` | `CONNECTS_TO` | `VM-ODOO-SERVER` | `outputs.tf` |
| E027 | `SSH-PROXYJUMP` | `CONNECTS_TO` | `VM-FULL-STACK-JS` | `outputs.tf` |
| E028 | `SSH-PROXYJUMP` | `CONNECTS_TO` | `VM-JAVA-JS` | `outputs.tf` |
| E029 | `SSH-CONFIG` | `IMPLEMENTS` | `SSH-PROXYJUMP` | ssh client config pattern |
| E030 | `SSH-SCP-VIA-JUMP` | `DEPENDS_ON` | `SSH-PROXYJUMP` | scp `-o ProxyJump` |
| E031 | `SG-BASTION` | `PROTECTS` | `VM-BASTION` | `bastion.tf` (port SG ids) |
| E032 | `SG-RULE-BASTION-SSH` | `PART_OF` | `SG-BASTION` | `security-groups.tf` |
| E033 | `SG-RULE-BASTION-ICMP` | `PART_OF` | `SG-BASTION` | `security-groups.tf` |
| E034 | `SG-RULE-BASTION-SSH` | `USES` | `TFVAR-ALLOWED-ADMIN-CIDR` | `security-groups.tf` (for_each) |
| E035 | `SG-PRIVATE-VMS` | `PROTECTS` | `VM-FULL-STACK-JS` | `existing-vms.tf` |
| E036 | `SG-PRIVATE-VMS` | `PROTECTS` | `VM-LMS-OPENEDX` | `existing-vms.tf` |
| E037 | `SG-PRIVATE-VMS` | `PROTECTS` | `VM-ODOO-SERVER` | tfvars (phase 2) |
| E038 | `SG-PRIVATE-VMS` | `PROTECTS` | `VM-JAVA-JS` | tfvars (phase 2) |
| E039 | `SG-RULE-VM-SSH-FROM-BASTION` | `PART_OF` | `SG-PRIVATE-VMS` | `security-groups.tf` |
| E040 | `SG-RULE-VM-ICMP-FROM-BASTION` | `PART_OF` | `SG-PRIVATE-VMS` | `security-groups.tf` |
| E041 | `SG-RULE-VM-SSH-FROM-BASTION` | `DEPENDS_ON` | `SG-BASTION` | `remote_group_id` |
| E042 | `SG-RULE-VM-ICMP-FROM-BASTION` | `DEPENDS_ON` | `SG-BASTION` | `remote_group_id` |
| E043 | `SG-ASSOC-PILOT-VMS` | `USES` | `SG-PRIVATE-VMS` | `existing-vms.tf` |
| E044 | `SG-ASSOC-PILOT-VMS` | `USES` | `TFVAR-EXISTING-VM-PORTS` | `existing-vms.tf` (for_each) |
| E045 | `SG-ASSOC-PILOT-VMS` | `CONFIGURES` | `VM-FULL-STACK-JS` | port association |
| E046 | `SG-ASSOC-PILOT-VMS` | `CONFIGURES` | `VM-LMS-OPENEDX` | port association |
| E047 | `SG-BASTION` | `IMPLEMENTS` | `PRIN-MIN-EXPOSURE` | CIDR-restricted ingress |
| E048 | `SG-PRIVATE-VMS` | `IMPLEMENTS` | `PRIN-SINGLE-ENTRY` | SSH only from bastion |
| E049 | `DEC-001` | `RELATED_TO` | `INFRA-FIP` | `bastion.tf` comment |
| E050 | `DEC-001` | `IMPLEMENTS` | `PRIN-NON-DESTRUCTIVE-TESTING` | — |
| E051 | `DEC-001` | `RELATED_TO` | `ISSUE-ORPHAN-FIP-SUBNET-VAR` | commented-out resource |
| E052 | `DEC-002` | `RELATED_TO` | `VM-BASTION` | lifecycle block |
| E053 | `DEC-002` | `RELATED_TO` | `INFRA-BASTION-PORT` | lifecycle block |
| E054 | `DEC-003` | `RELATED_TO` | `INFRA-CLOUDINIT` | `ignore_changes` |
| E055 | `DEC-003` | `RELATED_TO` | `ISSUE-USERDATA-DRIFT` | — |
| E056 | `DEC-004` | `RELATED_TO` | `SG-ASSOC-PILOT-VMS` | `enforce = false` |
| E057 | `DEC-005` | `RELATED_TO` | `SG-ASSOC-PILOT-VMS` | tfvars comments |
| E058 | `DEC-006` | `RELATED_TO` | `SSH-PROXYJUMP` | sshd `AllowAgentForwarding no` |
| E059 | `DEC-007` | `IMPLEMENTS` | `PRIN-SINGLE-ENTRY` | — |
| E060 | `DEC-008` | `IMPLEMENTS` | `PRIN-LEAST-PRIVILEGE` | `remote_group_id` |
| E061 | `DEC-009` | `RELATED_TO` | `INFRA-TFCLOUD` | `providers.tf` cloud block |
| E062 | `DEC-010` | `RELATED_TO` | `INFRA-KEYPAIR` | `variables.tf` default |
| E063 | `DEC-010` | `RELATED_TO` | `ISSUE-SHARED-KEYPAIR` | — |
| E064 | `DEC-011` | `RELATED_TO` | `INFRA-ANSIBLE` | ansible playbook |
| E065 | `DEC-012` | `RELATED_TO` | `INFRA-OPENSTACK-ENDPOINTS` | `providers.tf` |
| E066 | `DEC-012` | `RELATED_TO` | `ISSUE-LOCALHOST-ENDPOINTS` | — |
| E067 | `TFMOD-ROOT` | `CONFIGURES` | `VM-BASTION` | `bastion.tf` |
| E068 | `TFMOD-ROOT` | `CONFIGURES` | `INFRA-BASTION-PORT` | `bastion.tf` |
| E069 | `TFMOD-ROOT` | `CONFIGURES` | `INFRA-FIP-ASSOC` | `bastion.tf` |
| E070 | `TFMOD-ROOT` | `CONFIGURES` | `SG-BASTION` | `security-groups.tf` |
| E071 | `TFMOD-ROOT` | `CONFIGURES` | `SG-PRIVATE-VMS` | `security-groups.tf` |
| E072 | `TFMOD-ROOT` | `CONFIGURES` | `SG-ASSOC-PILOT-VMS` | `existing-vms.tf` |
| E073 | `TFMOD-ROOT` | `DEPENDS_ON` | `INFRA-OPENSTACK` | `providers.tf` |
| E074 | `TFMOD-ROOT` | `USES` | `INFRA-TFCLOUD` | `providers.tf` cloud block |
| E075 | `TFMOD-ROOT` | `GENERATES` | `TFOUT-BASTION-PRIVATE-IP` | `outputs.tf` |
| E076 | `TFMOD-ROOT` | `GENERATES` | `TFOUT-BASTION-FLOATING-IP` | `outputs.tf` |
| E077 | `TFMOD-ROOT` | `GENERATES` | `TFOUT-SSH-BASTION` | `outputs.tf` |
| E078 | `TFMOD-ROOT` | `GENERATES` | `TFOUT-SSH-LMS-OPENEDX` | `outputs.tf` |
| E079 | `TFMOD-ROOT` | `GENERATES` | `TFOUT-SSH-ODOO-SERVER` | `outputs.tf` |
| E080 | `TFMOD-ROOT` | `GENERATES` | `TFOUT-SSH-FULL-STACK-JS` | `outputs.tf` |
| E081 | `TFMOD-ROOT` | `GENERATES` | `TFOUT-SSH-JAVA-JS` | `outputs.tf` |
| E082 | `TFDATA-PRIVATE-NETWORK` | `DEPENDS_ON` | `NET-PRIVATE` | `data.tf` |
| E083 | `TFDATA-PRIVATE-SUBNET` | `DEPENDS_ON` | `NET-PRIVATE-SUBNET` | `data.tf` |
| E084 | `TFDATA-EXTERNAL-NETWORK` | `DEPENDS_ON` | `NET-EXTERNAL` | `data.tf` |
| E085 | `TFDATA-UBUNTU-IMAGE` | `DEPENDS_ON` | `INFRA-IMAGE` | `data.tf` |
| E086 | `TFDATA-BASTION-FLAVOR` | `DEPENDS_ON` | `INFRA-FLAVOR` | `data.tf` |
| E087 | `TFVAR-BASTION-FLOATING-IP` | `CONFIGURES` | `INFRA-FIP-ASSOC` | `bastion.tf` |
| E088 | `TFVAR-ADMIN-SSH-KEYS` | `CONFIGURES` | `INFRA-CLOUDINIT` | `bastion.tf` user_data |
| E089 | `TFVAR-EXISTING-KEYPAIR-NAME` | `CONFIGURES` | `VM-BASTION` | `bastion.tf` key_pair |
| E090 | `TFVAR-BASTION-NAME` | `CONFIGURES` | `VM-BASTION` | `bastion.tf` |
| E091 | `TFVAR-BASTION-IMAGE-NAME` | `CONFIGURES` | `TFDATA-UBUNTU-IMAGE` | `data.tf` |
| E092 | `TFVAR-BASTION-FLAVOR-NAME` | `CONFIGURES` | `TFDATA-BASTION-FLAVOR` | `data.tf` |
| E093 | `TFVAR-PRIVATE-NETWORK-NAME` | `CONFIGURES` | `TFDATA-PRIVATE-NETWORK` | `data.tf` |
| E094 | `TFVAR-PRIVATE-SUBNET-NAME` | `CONFIGURES` | `TFDATA-PRIVATE-SUBNET` | `data.tf` |
| E095 | `TFVAR-EXTERNAL-NETWORK-NAME` | `CONFIGURES` | `TFDATA-EXTERNAL-NETWORK` | `data.tf` |
| E096 | `TFVAR-OS-USERNAME` | `CONFIGURES` | `INFRA-OPENSTACK` auth | `providers.tf` |
| E097 | `TFVAR-OS-PASSWORD` | `CONFIGURES` | `INFRA-OPENSTACK` auth | `providers.tf` |
| E098 | `TFVAR-OS-PROJECT-NAME` | `CONFIGURES` | `INFRA-OPENSTACK` auth | `providers.tf` |
| E099 | `TFOUT-BASTION-PRIVATE-IP` | `DEPENDS_ON` | `INFRA-BASTION-PORT` | `outputs.tf` (all_fixed_ips) |
| E100 | `DEPLOY-PLAN` | `DEPENDS_ON` | `DEPLOY-INIT` | Terraform workflow |
| E101 | `DEPLOY-APPLY` | `DEPENDS_ON` | `DEPLOY-PLAN` | Terraform workflow |
| E102 | `DEPLOY-INIT` | `DEPENDS_ON` | `INFRA-TFCLOUD` | cloud backend auth |
| E103 | `DEPLOY-ROLLBACK` | `SUPERSEDES` | `DEPLOY-APPLY` | git revert + apply |
| E104 | `VAL-VALIDATE` | `VALIDATES` | `TFMOD-ROOT` | — |
| E105 | `VAL-PLAN` | `VALIDATES` | `TFMOD-ROOT` | — |
| E106 | `VAL-SSH-BASTION` | `VALIDATES` | `VM-BASTION` | — |
| E107 | `VAL-SSH-BASTION` | `VALIDATES` | `SG-BASTION` | — |
| E108 | `VAL-SSH-JUMP` | `VALIDATES` | `SG-PRIVATE-VMS` | — |
| E109 | `VAL-ICMP-PRIVATE` | `VALIDATES` | `SG-RULE-VM-ICMP-FROM-BASTION` | — |
| E110 | `VAL-SG-AUDIT` | `VALIDATES` | `SG-ASSOC-PILOT-VMS` | — |
| E111 | `VAL-HARDENING` | `VALIDATES` | `INFRA-CLOUDINIT` | — |
| E112 | `OP-ADD-VM` | `DEPENDS_ON` | `OP-RETRIEVE-PORT-ID` | — |
| E113 | `OP-ATTACH-TO-BASTION` | `PART_OF` | `OP-ADD-VM` | — |
| E114 | `OP-ATTACH-TO-BASTION` | `CONFIGURES` | `SG-ASSOC-PILOT-VMS` | `existing_vm_ports` |
| E115 | `OP-ADD-SSH-KEY` | `RELATED_TO` | `ISSUE-USERDATA-DRIFT` | — |
| E116 | `OP-VERIFY-ACCESS` | `USES` | `SSH-PROXYJUMP` | — |
| E117 | `OP-REMOVE-VM` | `CONFIGURES` | `SG-ASSOC-PILOT-VMS` | remove map entry + apply |
| E118 | `OP-CHANGE-ADMIN-CIDR` | `CONFIGURES` | `SG-RULE-BASTION-SSH` | `allowed_admin_cidrs` |
| E119 | `OP-ROLLBACK` | `USES` | `DEPLOY-ROLLBACK` | — |
| E120 | `OP-RUN-ANSIBLE` | `USES` | `INFRA-ANSIBLE` | — |
| E121 | `FW-ENFORCE-SG` | `SUPERSEDES` | `DEC-004` | post-test hardening |
| E122 | `FW-PORT-AUTODISCOVERY` | `SUPERSEDES` | `ISSUE-MANUAL-PORT-ID` | data-source port lookup |
| E123 | `RP-NGINX` | `IMPLEMENTS` | `FW-REVERSE-PROXY` | — |
| E124 | `RP-NGINX` | `DEPENDS_ON` | `VM-BASTION` | — |
| E125 | `FW-HTTPS` | `DEPENDS_ON` | `RP-NGINX` | — |
| E126 | `FW-HTTPS` | `DEPENDS_ON` | `FW-DOMAIN-DNS` | — |
| E127 | `FW-DOMAIN-DNS` | `DEPENDS_ON` | `FW-DNS-FIX` | — |
| E128 | `FW-DNS-FIX` | `RELATED_TO` | `ISSUE-DNS` | branch `fix/dns-terraform` |
| E129 | `FW-GRAFANA` | `DEPENDS_ON` | `FW-PROMETHEUS` | — |
| E130 | `FW-MERN-ONBOARDING` | `DEPENDS_ON` | `SG-ASSOC-PILOT-VMS` | tfvars placeholders |
| E131 | `FW-INVENTORY-AUTOMATION` | `DEPENDS_ON` | `INFRA-ANSIBLE` | empty `inventory.ini.example` |
| E132 | `ISSUE-HARDCODED-IPS` | `RELATED_TO` | `TFOUT-SSH-LMS-OPENEDX` | `outputs.tf` (applies to all ssh_* outputs) |
| E133 | `ISSUE-LOCALHOST-ENDPOINTS` | `RELATED_TO` | `DEPLOY-INIT` | runs need 127.0.0.1 reachability |
| E134 | `VM-LMS-OPENEDX` | `DEPENDS_ON` | `NET-PRIVATE` | fixed IP `192.168.100.55` |
| E135 | `VM-ODOO-SERVER` | `DEPENDS_ON` | `NET-PRIVATE` | fixed IP `192.168.100.91` |
| E136 | `VM-FULL-STACK-JS` | `DEPENDS_ON` | `NET-PRIVATE` | fixed IP `192.168.100.87` |
| E137 | `VM-JAVA-JS` | `DEPENDS_ON` | `NET-PRIVATE` | fixed IP `192.168.100.149` |

---

## 3. Layer Views (retrieval filters)

- **Infrastructure Layer:** `INFRA-OPENSTACK`, `INFRA-IMAGE`, `INFRA-FLAVOR`, all `VM-*`
- **Networking Layer:** `NET-*`, `INFRA-BASTION-PORT`, `INFRA-FIP`, `INFRA-FIP-ASSOC`, `INFRA-OPENSTACK-ENDPOINTS`
- **Security Layer:** `SG-*`, `INFRA-KEYPAIR`, `INFRA-CLOUDINIT`, `INFRA-ANSIBLE`, `TFVAR-ADMIN-SSH-KEYS`, `TFVAR-ALLOWED-ADMIN-CIDR`
- **Terraform Layer:** `TFMOD-ROOT`, `TFVAR-*`, `TFOUT-*`, `TFDATA-*`, `DEPLOY-*`, `INFRA-TFCLOUD`
- **Operational Layer:** `OP-*`, `VAL-*`, `SSH-*`, `DEC-*`, `PRIN-*`, `ISSUE-*`, `FW-*`, `ACTOR-ADMINS`

---

## AI Retrieval Optimization

- **Keywords:** graph index, node registry, edge table, master relationships, dependency graph, topology, terraform-bastion, OpenStack bastion
- **Tags:** #index #registry #edges #topology #graphrag
- **Related Nodes:** all nodes (this is the master index)
- **Parent Nodes:** none
- **Child Nodes:** every registry entry
- **Cross References:** `graph.json` (machine-readable mirror), `docs/README.md` (schema)
- **Aliases:** graph database, master index, topology map
- **Layers:** all layers
