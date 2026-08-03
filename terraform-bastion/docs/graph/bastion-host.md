# Feature: Bastion Host

> Home document for: `VM-BASTION`, `INFRA-BASTION-PORT`, `INFRA-FIP`, `INFRA-FIP-ASSOC`,
> `INFRA-KEYPAIR`, `INFRA-IMAGE`, `INFRA-FLAVOR`, `INFRA-CLOUDINIT`, `INFRA-ANSIBLE`,
> `ISSUE-USERDATA-DRIFT`, `ISSUE-SHARED-KEYPAIR`

---

## Overview

- **Purpose:** Provide a single, hardened, auditable SSH entry point into the private
  OpenStack network (`NET-PRIVATE`) so that no internal VM needs any public exposure.
- **Context:** The project migrates pre-existing, manually-created training VMs
  (LMS-OpenedX, Odoo, Full-Stack-JS, Java-JS) to infrastructure-as-code on OpenStack.
  Before the bastion, VMs were reached through individually managed access paths.
- **Problem solved:** Eliminates scattered public SSH exposure, centralizes
  authentication (key-based only), and creates one choke point to harden, monitor,
  and (later) extend with a reverse proxy.
- **Why it exists:** Implements `PRIN-SINGLE-ENTRY` and `PRIN-MIN-EXPOSURE`
  (→ See: [decisions.md](decisions.md)).

---

## Architecture

### Components

1. **Neutron port** (`INFRA-BASTION-PORT`) — created and owned by Terraform, attached
   to `NET-PRIVATE` / `NET-PRIVATE-SUBNET`, pinned to `SG-BASTION`.
2. **Compute instance** (`VM-BASTION`) — Ubuntu 22.04 on `m1.small-custom`, booted with
   the existing keypair `Full_Stack_JS_key`, attached *only* via the managed port.
3. **Floating IP association** (`INFRA-FIP-ASSOC`) — binds a **pre-existing** Floating IP
   (`INFRA-FIP`) to the port. Terraform associates but never creates the FIP (`DEC-001`).
4. **Cloud-init** (`INFRA-CLOUDINIT`) — first-boot hardening baked into `user_data`.
5. **Ansible playbook** (`INFRA-ANSIBLE`) — the steady-state hardening path that
   *replaces* cloud-init for any post-boot change (`DEC-003`).

### Interactions & data flow

```
ACTOR-ADMINS ──SSH:22──> INFRA-FIP ──(DNAT)──> INFRA-BASTION-PORT ──> VM-BASTION
                                                              │ sshd hardened by
                                                              ├─ INFRA-CLOUDINIT (first boot)
                                                              └─ INFRA-ANSIBLE  (steady state)
VM-BASTION ──SSH:22──> VM-* (allowed by SG-PRIVATE-VMS via remote_group_id)
```

### Security boundaries

- **Public → Bastion:** only TCP/22 from `TFVAR-ALLOWED-ADMIN-CIDR` (`SG-RULE-BASTION-SSH`).
- **Bastion → VMs:** only TCP/22 + ICMP, granted by `SG-PRIVATE-VMS` referencing
  `SG-BASTION` as `remote_group_id` (`DEC-008`).
- **Host-level:** password auth off, root login off, agent forwarding off (`DEC-006`),
  fail2ban + auditd + unattended-upgrades active.

---

## Graph Nodes

### `VM-BASTION` — Bastion Host `bastion-nawel-test`

- **Type:** VM · **Layer:** Infrastructure + Security
- **Description:** OpenStack compute instance (`openstack_compute_instance_v2.bastion`),
  the only VM reachable from outside the private network.
- **Purpose:** Single secure SSH entrypoint; jump host for all internal VMs.
- **Dependencies:** `INFRA-BASTION-PORT`, `INFRA-IMAGE`, `INFRA-FLAVOR`, `INFRA-KEYPAIR`,
  `INFRA-CLOUDINIT`, `NET-PRIVATE`; protected by `SG-BASTION`; reached via `INFRA-FIP`.
- **Related Components:** `SG-ASSOC-PILOT-VMS` (grants it SSH into pilot VMs),
  `SSH-PROXYJUMP`, `RP-NGINX` (future).
- **Files involved:** `bastion.tf` (lines 19–72), `variables.tf` (`bastion_*`),
  `data.tf` (image/flavor lookups).
- **Commands:** `ssh ubuntu@<floating-ip>` (see `TFOUT-SSH-BASTION`);
  `openstack server show bastion-nawel-test`.
- **Validation procedure:** `VAL-SSH-BASTION`, `VAL-HARDENING` (→ See: [operations.md](operations.md)).
- **Risks:** single point of failure for all admin access; `prevent_destroy` blocks
  teardown (intentional, `DEC-002`); `ISSUE-SHARED-KEYPAIR`.
- **Future improvements:** `FW-REVERSE-PROXY` on this host; monitoring agent
  (`FW-PROMETHEUS`); dedicated keypair (resolves `ISSUE-SHARED-KEYPAIR`).

### `INFRA-BASTION-PORT` — Neutron Port `bastion-nawel-test-port`

- **Type:** Infrastructure Component · **Layer:** Networking
- **Description:** `openstack_networking_port_v2.bastion`; a Terraform-managed port on
  `NET-PRIVATE` with `admin_state_up = true`, `SG-BASTION` attached, and a `fixed_ip`
  allocated from `NET-PRIVATE-SUBNET`.
- **Purpose:** Decouples the network identity (IP, SGs, FIP target) from the compute
  lifecycle; the FIP association targets this port, not the server.
- **Dependencies:** `TFDATA-PRIVATE-NETWORK`, `TFDATA-PRIVATE-SUBNET`, `SG-BASTION`.
- **Related Components:** `VM-BASTION` (consumes it), `INFRA-FIP-ASSOC` (targets it),
  `TFOUT-BASTION-PRIVATE-IP` (reads `all_fixed_ips[0]`).
- **Files involved:** `bastion.tf` (lines 1–17).
- **Commands:** `openstack port show bastion-nawel-test-port`.
- **Validation procedure:** port shows `ACTIVE`, one fixed IP in `192.168.100.0/24`,
  security group = `sg-bastion-nawel-test` (`VAL-SG-AUDIT`).
- **Risks:** `prevent_destroy` (intentional); deleting it would orphan the FIP association.
- **Future improvements:** fixed IP explicitly pinned to a chosen address if the
  reverse proxy needs a stable internal origin IP.

### `INFRA-FIP` — Pre-existing Floating IP

- **Type:** Infrastructure Component · **Layer:** Networking
- **Description:** A Floating IP allocated **outside** Terraform (manually, beforehand)
  from pool `NET-EXTERNAL` (`public`). Its address value is injected through
  `TFVAR-BASTION-FLOATING-IP`.
- **Purpose:** Stable public identity of the bastion; survives Terraform teardown.
- **Dependencies:** `NET-EXTERNAL`.
- **Related Components:** `INFRA-FIP-ASSOC` (binds it), `TFOUT-BASTION-FLOATING-IP`,
  all `TFOUT-SSH-*` (embed it), `DEC-001`.
- **Files involved:** `bastion.tf` (commented-out managed resource, lines 74–84;
  association lines 86–89), `variables.tf` (`bastion_floating_ip`).
- **Commands:** `openstack floating ip list`, `openstack floating ip show <ip>`.
- **Validation procedure:** `VAL-SSH-BASTION` (reachability), FIP status `ACTIVE`
  and mapped to `bastion-nawel-test-port`.
- **Risks:** not under Terraform lifecycle control — can be deleted/mapped externally
  without `plan` detecting intent; address is a secret-adjacent value kept in tfvars.
- **Future improvements:** `FW-DOMAIN-DNS` record pointing at it; optionally import the
  FIP into state once the team accepts Terraform ownership.

### `INFRA-FIP-ASSOC` — Floating IP ↔ Port Association

- **Type:** Infrastructure Component · **Layer:** Networking
- **Description:** `openstack_networking_floatingip_associate_v2.bastion`; binds
  `INFRA-FIP` to `INFRA-BASTION-PORT`.
- **Purpose:** Makes the bastion reachable from outside without Terraform owning the FIP.
- **Dependencies:** `INFRA-FIP` (via `TFVAR-BASTION-FLOATING-IP`), `INFRA-BASTION-PORT`.
- **Related Components:** `SSH-DIRECT-BASTION`, `SSH-PROXYJUMP` (both traverse it).
- **Files involved:** `bastion.tf` (lines 86–89).
- **Commands:** `openstack floating ip show <ip>` → check `port_id`.
- **Validation procedure:** FIP `port_id` equals the ID of `bastion-nawel-test-port`.
- **Risks:** re-association flaps if the port is recreated; no `prevent_destroy` here
  (by design — association is cheap and reversible).
- **Future improvements:** none required; subsumed by `FW-REVERSE-PROXY` for HTTP(S).

### `INFRA-KEYPAIR` — Keypair `Full_Stack_JS_key`

- **Type:** Infrastructure Component · **Layer:** Security
- **Description:** Pre-existing OpenStack keypair, injected into the bastion at boot by
  Nova; selected via `TFVAR-EXISTING-KEYPAIR-NAME`.
- **Purpose:** Bootstrap SSH identity for the default `ubuntu` user.
- **Dependencies:** none in-graph (created manually in OpenStack).
- **Related Components:** `VM-BASTION` (uses it), `TFVAR-ADMIN-SSH-KEYS` (cloud-init adds
  more keys), `ISSUE-SHARED-KEYPAIR`.
- **Files involved:** `bastion.tf` (`key_pair`), `variables.tf`, `terraform.tfvars.example`.
- **Commands:** `openstack keypair show Full_Stack_JS_key`.
- **Validation procedure:** keypair fingerprint matches the local private key used for
  `VAL-SSH-BASTION`.
- **Risks:** `ISSUE-SHARED-KEYPAIR` — one shared keypair across VMs widens blast radius
  if the private key leaks.
- **Future improvements:** dedicated per-host keypairs; Vault-distributed keys (`FW-VAULT`).

### `INFRA-IMAGE` — Glance Image `Ubuntu-22.04`

- **Type:** Infrastructure Component · **Layer:** Infrastructure
- **Description:** Resolved by `TFDATA-UBUNTU-IMAGE` with `most_recent = true`.
- **Purpose:** Base OS for the bastion.
- **Dependencies:** none (Glance content).
- **Related Components:** `VM-BASTION`, `TFVAR-BASTION-IMAGE-NAME`.
- **Files involved:** `data.tf`, `variables.tf`.
- **Commands:** `openstack image show Ubuntu-22.04`.
- **Validation procedure:** image status `active`.
- **Risks:** `most_recent = true` means a new image upload silently changes what a
  *rebuilt* bastion would boot (drift on rebuild, not on apply — instance is protected).
- **Future improvements:** pin `image_id` digest for reproducible rebuilds.

### `INFRA-FLAVOR` — Flavor `m1.small-custom`

- **Type:** Infrastructure Component · **Layer:** Infrastructure
- **Description:** Resolved by `TFDATA-BASTION-FLAVOR`; sizing for the bastion.
- **Purpose:** Right-sized, cheap jump host (SSH forwarding needs minimal CPU/RAM).
- **Dependencies:** none. **Related Components:** `VM-BASTION`, `TFVAR-BASTION-FLAVOR-NAME`.
- **Files involved:** `data.tf`, `variables.tf`.
- **Commands:** `openstack flavor show m1.small-custom`.
- **Validation procedure:** flavor exists and matches expected vCPU/RAM/disk.
- **Risks:** resizing requires instance recreation/rebuild path (protected by `DEC-002`).
- **Future improvements:** revisit sizing if `RP-NGINX` + monitoring agents land here.

### `INFRA-CLOUDINIT` — Bastion Cloud-Init Hardening

- **Type:** Infrastructure Component · **Layer:** Security
- **Description:** The `user_data` cloud-config of `VM-BASTION`: `ssh_pwauth: false`,
  `disable_root: true`, injects `TFVAR-ADMIN-SSH-KEYS`, installs `fail2ban`, `auditd`,
  `unattended-upgrades`, writes `/etc/ssh/sshd_config.d/99-bastion.conf`
  (PasswordAuthentication no, KbdInteractiveAuthentication no, PermitRootLogin no,
  PubkeyAuthentication yes, AllowAgentForwarding no, X11Forwarding no, PermitTunnel no,
  MaxAuthTries 3, ClientAliveInterval 300, ClientAliveCountMax 2), then restarts `ssh`
  and enables `fail2ban` + `auditd`.
- **Purpose:** First-boot security baseline — the bastion is born hardened.
- **Dependencies:** `TFVAR-ADMIN-SSH-KEYS`.
- **Related Components:** `INFRA-ANSIBLE` (mirror + successor), `DEC-003`,
  `ISSUE-USERDATA-DRIFT`, `VAL-HARDENING`.
- **Files involved:** `bastion.tf` (lines 29–63).
- **Commands:** `cloud-init status --wait`, `cat /etc/ssh/sshd_config.d/99-bastion.conf`.
- **Validation procedure:** `VAL-HARDENING` (→ See: [operations.md](operations.md)).
- **Risks:** `ISSUE-USERDATA-DRIFT` — edits to `user_data` are ignored after creation
  (`ignore_changes`); never rely on cloud-init for post-boot change.
- **Future improvements:** none for this node by design — change path is `INFRA-ANSIBLE`.

### `INFRA-ANSIBLE` — Ansible Playbook `bastion-hardening.yml`

- **Type:** Infrastructure Component · **Layer:** Security
- **Description:** Playbook targeting host group `bastion` with `become: true`; installs
  the same security packages, deploys the same `99-bastion.conf` (with a `Restart SSH`
  handler), and enables fail2ban/auditd. Idempotent mirror of `INFRA-CLOUDINIT`.
- **Purpose:** Steady-state configuration management; the **only** supported way to
  change bastion hardening after first boot (`DEC-003`, `DEC-011`).
- **Dependencies:** `VM-BASTION` reachable via SSH (`SSH-DIRECT-BASTION`),
  a local `ansible/inventory.ini` (gitignored; template `inventory.ini.example` is
  currently empty — see `FW-INVENTORY-AUTOMATION`).
- **Related Components:** `OP-RUN-ANSIBLE`, `VAL-HARDENING`, `FW-INVENTORY-AUTOMATION`.
- **Files involved:** `ansible/bastion-hardening.yml`, `ansible/inventory.ini.example`,
  `.gitignore` (`ansible/inventory.ini`).
- **Commands:** `ansible-playbook -i ansible/inventory.ini ansible/bastion-hardening.yml`.
- **Validation procedure:** playbook run reports `ok`/`changed=0` on re-run;
  `VAL-HARDENING` checks on the host.
- **Risks:** drift between playbook and cloud-init if only one is edited (keep them in
  sync — they are intentionally mirrored); empty inventory template slows onboarding.
- **Future improvements:** `FW-INVENTORY-AUTOMATION` (generate inventory from
  `terraform output`); extend playbook with node exporter for `FW-PROMETHEUS`.

### `ISSUE-USERDATA-DRIFT` — Cloud-init changes never re-apply

- **Type:** Known Issue · **Layer:** Terraform + Operational
- **Description:** `VM-BASTION` sets `lifecycle { ignore_changes = [user_data] }`
  (`DEC-003`). Any edit to the cloud-config — including `admin_ssh_keys` — is silently
  ignored by `plan`/`apply` after the instance exists.
- **Impact:** `OP-ADD-SSH-KEY` **cannot** be done via tfvars alone; operators must use
  Ansible or manual `authorized_keys` edits.
- **Files involved:** `bastion.tf` (lines 65–71).
- **Mitigation:** document the Ansible path (this graph); long-term, move
  `ssh_authorized_keys` management fully into `INFRA-ANSIBLE`.
- **Related:** `TFVAR-ADMIN-SSH-KEYS`, `OP-ADD-SSH-KEY`, `DEC-003`.

### `ISSUE-SHARED-KEYPAIR` — One keypair reused across VMs

- **Type:** Known Issue · **Layer:** Security
- **Description:** `Full_Stack_JS_key` (created for the Full-Stack-JS VM) is reused as
  the bastion's boot keypair (`DEC-010`), and the same name suggests reuse elsewhere.
- **Impact:** compromise of one private key unlocks multiple machines; rotation touches
  several servers at once.
- **Files involved:** `variables.tf` (`existing_keypair_name` default), `bastion.tf`.
- **Mitigation:** least-privilege SGs limit lateral movement; keys additionally gated by
  `TFVAR-ALLOWED-ADMIN-CIDR`.
- **Related:** `INFRA-KEYPAIR`, `DEC-010`, `FW-VAULT`.

---

## Graph Relationships (local view)

```
VM-BASTION        USES            INFRA-BASTION-PORT · INFRA-IMAGE · INFRA-FLAVOR · INFRA-KEYPAIR
VM-BASTION        CONNECTS_TO     NET-PRIVATE
VM-BASTION        IS_ACCESSED_VIA INFRA-FIP
INFRA-BASTION-PORT CONNECTS_TO    NET-PRIVATE
INFRA-BASTION-PORT USES           NET-PRIVATE-SUBNET
INFRA-FIP-ASSOC   CONNECTS_TO     INFRA-BASTION-PORT
INFRA-FIP-ASSOC   USES            INFRA-FIP
INFRA-FIP         PART_OF         NET-EXTERNAL
INFRA-CLOUDINIT   CONFIGURES      VM-BASTION
INFRA-ANSIBLE     CONFIGURES      VM-BASTION
INFRA-ANSIBLE     REPLACES        INFRA-CLOUDINIT          (post-boot changes, DEC-003)
SG-BASTION        PROTECTS        VM-BASTION
TFVAR-ADMIN-SSH-KEYS    CONFIGURES INFRA-CLOUDINIT
TFVAR-EXISTING-KEYPAIR-NAME CONFIGURES VM-BASTION
TFVAR-BASTION-FLOATING-IP   CONFIGURES INFRA-FIP-ASSOC
ACTOR-ADMINS      CONNECTS_TO     VM-BASTION
VAL-SSH-BASTION   VALIDATES       VM-BASTION
VAL-HARDENING     VALIDATES       INFRA-CLOUDINIT
ISSUE-USERDATA-DRIFT RELATED_TO   INFRA-CLOUDINIT · DEC-003
ISSUE-SHARED-KEYPAIR  RELATED_TO  INFRA-KEYPAIR · DEC-010
```

---

## Decisions (canonical text in [decisions.md](decisions.md))

- `DEC-001` — Floating IP pre-exists; Terraform only associates it.
- `DEC-002` — `prevent_destroy` on instance and port.
- `DEC-003` — `ignore_changes = [user_data]`; post-boot change path = Ansible.
- `DEC-010` — Reuse keypair `Full_Stack_JS_key` (accepts `ISSUE-SHARED-KEYPAIR`).
- `DEC-011` — Dual hardening: cloud-init (birth) + Ansible (life).

---

## Terraform Knowledge

| Resource | File | Key attributes | Lifecycle |
|---|---|---|---|
| `openstack_networking_port_v2.bastion` | `bastion.tf` | network from `TFDATA-PRIVATE-NETWORK`, fixed_ip from `TFDATA-PRIVATE-SUBNET`, SG `SG-BASTION` | `prevent_destroy = true` |
| `openstack_compute_instance_v2.bastion` | `bastion.tf` | name `TFVAR-BASTION-NAME`, image `TFDATA-UBUNTU-IMAGE`, flavor `TFDATA-BASTION-FLAVOR`, `key_pair`, `user_data` cloud-init | `prevent_destroy = true`, `ignore_changes = [user_data]` |
| `openstack_networking_floatingip_associate_v2.bastion` | `bastion.tf` | `floating_ip = TFVAR-BASTION-FLOATING-IP`, `port_id = INFRA-BASTION-PORT` | — |
| ~~`openstack_networking_floatingip_v2.bastion`~~ | `bastion.tf` (commented) | disabled by `DEC-001` | n/a |

**Execution order (implicit DAG):** `SG-BASTION` → `INFRA-BASTION-PORT` →
`VM-BASTION` ∥ `INFRA-FIP-ASSOC` (both depend on the port).

---

## Infrastructure Workflow

1. `DEPLOY-INIT` / `DEPLOY-PLAN` / `DEPLOY-APPLY` (→ See: [terraform-platform.md](terraform-platform.md)).
2. Wait for cloud-init: `ssh ubuntu@<fip> 'cloud-init status --wait'`.
3. `VAL-SSH-BASTION` then `VAL-HARDENING`.
4. Steady-state changes: edit `ansible/bastion-hardening.yml` → `OP-RUN-ANSIBLE`.

---

## Validation

- `VAL-SSH-BASTION`: `ssh ubuntu@<floating-ip>` succeeds, password auth refused.
- `VAL-HARDENING`: `systemctl is-active fail2ban auditd`; `sshd -T | grep -E 'passwordauthentication|permitrootlogin'` → `no`.
- `VAL-SG-AUDIT`: `openstack port show bastion-nawel-test-port` shows `SG-BASTION` only.

---

## Operational Procedures

Feature-specific (full runbook in [operations.md](operations.md)):

- **Access the bastion** → `SSH-DIRECT-BASTION` (→ See: [ssh-workflows.md](ssh-workflows.md)).
- **Add an SSH key** → `OP-ADD-SSH-KEY` — *do not* rely on `admin_ssh_keys` + apply
  (`ISSUE-USERDATA-DRIFT`); use Ansible or append to
  `/home/ubuntu/.ssh/authorized_keys` on the host.
- **Rebuild the bastion** → temporarily lift `prevent_destroy`, `terraform taint`
  is *not sufficient* (lifecycle still blocks destroy); remove the lifecycle block,
  apply (destroy+recreate), restore the block, apply again, then re-run `OP-RUN-ANSIBLE`.

---

## Future Roadmap

- `FW-REVERSE-PROXY` / `RP-NGINX` `DEPENDS_ON` `VM-BASTION`.
- `FW-PROMETHEUS` node exporter on `VM-BASTION`.
- `FW-VAULT` to retire `ISSUE-SHARED-KEYPAIR` and tfvars-held secrets.
- `FW-DOMAIN-DNS` A-record targeting `INFRA-FIP`.

---

## AI Retrieval Optimization

- **Keywords:** bastion, jump host, bastion-nawel-test, floating IP, neutron port, cloud-init, user_data, hardening, fail2ban, auditd, sshd 99-bastion.conf, keypair Full_Stack_JS_key, Ubuntu-22.04, m1.small-custom, prevent_destroy, ignore_changes
- **Tags:** #bastion #compute #hardening #cloud-init #ansible #floating-ip #security
- **Related Nodes:** `SG-BASTION`, `SSH-PROXYJUMP`, `NET-PRIVATE`, `TFOUT-SSH-*`, `RP-NGINX`
- **Parent Nodes:** `TFMOD-ROOT`, `PRIN-SINGLE-ENTRY`
- **Child Nodes:** `VM-BASTION`, `INFRA-BASTION-PORT`, `INFRA-FIP`, `INFRA-FIP-ASSOC`, `INFRA-KEYPAIR`, `INFRA-IMAGE`, `INFRA-FLAVOR`, `INFRA-CLOUDINIT`, `INFRA-ANSIBLE`
- **Cross References:** [security-model.md](security-model.md), [ssh-workflows.md](ssh-workflows.md), [operations.md](operations.md), [decisions.md](decisions.md)
- **Aliases:** serveur rebond (fr), jump box, SSH gateway, bastion host Nawel
- **Infrastructure Layer:** `VM-BASTION`, `INFRA-IMAGE`, `INFRA-FLAVOR`
- **Networking Layer:** `INFRA-BASTION-PORT`, `INFRA-FIP`, `INFRA-FIP-ASSOC`
- **Security Layer:** `INFRA-KEYPAIR`, `INFRA-CLOUDINIT`, `INFRA-ANSIBLE`
- **Terraform Layer:** `bastion.tf` resources, `TFVAR-BASTION-*`
- **Operational Layer:** `OP-ADD-SSH-KEY`, `OP-RUN-ANSIBLE`, `VAL-SSH-BASTION`, `VAL-HARDENING`
