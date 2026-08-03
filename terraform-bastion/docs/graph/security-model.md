# Feature: Security Model (Security Groups & Trust Boundaries)

> Home document for: `SG-BASTION`, `SG-RULE-BASTION-SSH`, `SG-RULE-BASTION-ICMP`,
> `SG-PRIVATE-VMS`, `SG-RULE-VM-SSH-FROM-BASTION`, `SG-RULE-VM-ICMP-FROM-BASTION`

---

## Overview

- **Purpose:** Enforce, at the Neutron port level, exactly two traffic flows:
  (1) admins → bastion over SSH, (2) bastion → internal VMs over SSH/ICMP. Everything
  else inbound is denied by default.
- **Context:** VMs pre-date the automation effort and may carry legacy security groups.
  The model therefore *adds* rules non-destructively (`DEC-004`) instead of replacing
  existing attachments during the pilot.
- **Problem solved:** Removes the need for per-VM public exposure and for brittle
  CIDR lists of internal machines; trust is expressed as "comes from the bastion",
  not "comes from an IP".
- **Why it exists:** Direct implementation of `PRIN-SINGLE-ENTRY`, `PRIN-MIN-EXPOSURE`,
  `PRIN-LEAST-PRIVILEGE` (→ See: [decisions.md](decisions.md)).

---

## Architecture

### Components

1. **`SG-BASTION`** — attached to `INFRA-BASTION-PORT`; ingress: SSH/22 from
   `TFVAR-ALLOWED-ADMIN-CIDR` (one rule per CIDR via `for_each`), ICMP from
   `192.168.100.0/24`. Default egress rules kept (`delete_default_rules = false`).
2. **`SG-PRIVATE-VMS`** — attached to existing VM ports through `SG-ASSOC-PILOT-VMS`;
   ingress: SSH/22 + ICMP **from `SG-BASTION`** (`remote_group_id`, `DEC-008`).
   Default egress kept as well.

### Interaction / data flow

```
ACTOR-ADMINS (IP ∈ allowed_admin_cidrs)
   │ tcp/22  ── evaluated by SG-RULE-BASTION-SSH ──▶ INFRA-BASTION-PORT ─▶ VM-BASTION
   │ any other source IP ──✗ dropped
VM-BASTION (port tagged SG-BASTION)
   │ tcp/22, icmp ── evaluated by remote_group_id rules ──▶ VM-* ports
   │ source NOT tagged SG-BASTION ──✗ dropped
```

### Security boundaries

- **B1 public perimeter:** `SG-RULE-BASTION-SSH` — the *only* public ingress in the project.
- **B2 internal perimeter:** `SG-RULE-VM-SSH-FROM-BASTION` — internal VMs accept SSH
  exclusively from ports carrying `SG-BASTION`.
- **B3 diagnostics plane:** ICMP rules (both SGs) enable `VAL-ICMP-PRIVATE` without
  opening any additional TCP/UDP surface.
- Note: `remote_group_id` follows the *security group tag on the source port*, so the
  trust anchor is port configuration, not IP addressing — resilient to IP changes.

---

## Graph Nodes

### `SG-BASTION` — `sg-bastion-nawel-test`

- **Type:** Security Group · **Layer:** Security
- **Description:** `openstack_networking_secgroup_v2.bastion`; description "SSH public
  vers le Bastion uniquement"; default rules retained.
- **Purpose:** The single public ingress policy of the whole infrastructure.
- **Dependencies:** none (root SG).
- **Related Components:** protects `VM-BASTION` via `INFRA-BASTION-PORT`; referenced by
  `SG-RULE-VM-*-FROM-BASTION` (`remote_group_id`); rules `SG-RULE-BASTION-SSH`,
  `SG-RULE-BASTION-ICMP`.
- **Files involved:** `security-groups.tf` (lines 1–5), `bastion.tf` (port attachment).
- **Commands:** `openstack security group show sg-bastion-nawel-test`.
- **Validation procedure:** `VAL-SG-AUDIT` — only expected ingress rules present;
  attached to exactly one port.
- **Risks:** overly broad CIDR in `TFVAR-ALLOWED-ADMIN-CIDR` (e.g. `0.0.0.0/0`) silently
  re-exposes SSH to the Internet — always use `/32`.
- **Future improvements:** `FW-REVERSE-PROXY` will add 80/443 rules here; consider
  disabling default egress or scoping it.

### `SG-RULE-BASTION-SSH` — SSH/22 from allowed admin CIDRs

- **Type:** Security Group (rule) · **Layer:** Security
- **Description:** `openstack_networking_secgroup_rule_v2.bastion_ssh`;
  `for_each = toset(var.allowed_admin_cidrs)` → one ingress IPv4 tcp/22 rule per CIDR.
- **Purpose:** Restricts public SSH to named admin locations.
- **Dependencies:** `SG-BASTION`, `TFVAR-ALLOWED-ADMIN-CIDR`.
- **Related Components:** `OP-CHANGE-ADMIN-CIDR` (its operational interface),
  `VAL-SSH-BASTION`.
- **Files involved:** `security-groups.tf` (lines 7–17), `variables.tf`, tfvars.
- **Commands:** `openstack security group rule list sg-bastion-nawel-test`.
- **Validation procedure:** rule count == length of `allowed_admin_cidrs`; no `0.0.0.0/0`
  unless deliberately temporary.
- **Risks:** adding/removing CIDRs is an in-place change (no recreation) — instant effect,
  no maintenance window; a typo can lock admins out (keep one known-good CIDR last in
  the change).
- **Future improvements:** per-admin named rules; geofencing/VPN-only ingress later.

### `SG-RULE-BASTION-ICMP` — ICMP from `192.168.100.0/24`

- **Type:** Security Group (rule) · **Layer:** Security
- **Description:** `openstack_networking_secgroup_rule_v2.bastion_icmp_private`;
  ingress ICMP from the private subnet CIDR (literal).
- **Purpose:** Lets internal VMs ping the bastion (diagnostics, `VAL-ICMP-PRIVATE`).
- **Dependencies:** `SG-BASTION`; CIDR mirrors `NET-PRIVATE-SUBNET`.
- **Related Components:** `SG-RULE-VM-ICMP-FROM-BASTION` (mirror rule).
- **Files involved:** `security-groups.tf` (lines 19–25).
- **Commands:** included in `VAL-SG-AUDIT`.
- **Validation procedure:** `ping <bastion-private-ip>` from any internal VM succeeds.
- **Risks:** CIDR literal drifts if subnet is renumbered (see networking.md risk).
- **Future improvements:** parameterize CIDR via a shared variable.

### `SG-PRIVATE-VMS` — `sg-private-vms-via-bastion-test`

- **Type:** Security Group · **Layer:** Security
- **Description:** `openstack_networking_secgroup_v2.private_vms`; description "SSH privé
  uniquement depuis le Bastion"; attached to existing VM ports by `SG-ASSOC-PILOT-VMS`.
- **Purpose:** The internal trust policy: "SSH only if it came through the bastion."
- **Dependencies:** `SG-BASTION` (its rules reference it).
- **Related Components:** protects `VM-FULL-STACK-JS`, `VM-LMS-OPENEDX` (phase 1),
  `VM-ODOO-SERVER`, `VM-JAVA-JS` (phase 2), later `VM-MERN-*`.
- **Files involved:** `security-groups.tf` (lines 27–31), `existing-vms.tf`.
- **Commands:** `openstack security group show sg-private-vms-via-bastion-test`.
- **Validation procedure:** `VAL-SSH-JUMP` succeeds; direct SSH to a VM's private IP from
  an admin laptop (not via bastion) **fails** — that failure *is* the validation.
- **Risks:** with `DEC-004` (`enforce = false`), legacy SGs on a VM port may still allow
  other paths; the model is additive until `FW-ENFORCE-SG`.
- **Future improvements:** `FW-ENFORCE-SG` (make this SG the only one on VM ports).

### `SG-RULE-VM-SSH-FROM-BASTION` — SSH/22 from bastion SG

- **Type:** Security Group (rule) · **Layer:** Security
- **Description:** `openstack_networking_secgroup_rule_v2.vm_ssh_from_bastion`; ingress
  tcp/22 with `remote_group_id = SG-BASTION.id` (**not** a CIDR — `DEC-008`).
- **Purpose:** Authorizes bastion-sourced SSH to any protected VM, immune to bastion IP
  changes.
- **Dependencies:** `SG-PRIVATE-VMS`, `SG-BASTION`.
- **Related Components:** `SSH-PROXYJUMP` (relies on it), `VAL-SSH-JUMP`.
- **Files involved:** `security-groups.tf` (lines 33–41).
- **Commands:** `openstack security group rule list sg-private-vms-via-bastion-test`.
- **Validation procedure:** rule shows `remote_group_id` equal to the bastion SG ID.
- **Risks:** if the bastion's port loses `SG-BASTION`, *all* internal SSH breaks at once
  (single trust anchor — by design, but know it).
- **Future improvements:** none; this is the end-state pattern.

### `SG-RULE-VM-ICMP-FROM-BASTION` — ICMP from bastion SG

- **Type:** Security Group (rule) · **Layer:** Security
- **Description:** `openstack_networking_secgroup_rule_v2.vm_icmp_from_bastion`; ingress
  ICMP with `remote_group_id = SG-BASTION.id`.
- **Purpose:** Bastion → VM ping for `VAL-ICMP-PRIVATE` and troubleshooting.
- **Dependencies:** `SG-PRIVATE-VMS`, `SG-BASTION`.
- **Related Components:** `SG-RULE-BASTION-ICMP` (mirror), `OP-VERIFY-ACCESS`.
- **Files involved:** `security-groups.tf` (lines 43–49).
- **Commands:** from bastion: `ping -c3 192.168.100.87` (etc.).
- **Validation procedure:** ping each pilot VM from the bastion succeeds.
- **Risks:** none material.
- **Future improvements:** none.

---

## Graph Relationships (local view)

```
SG-BASTION      PROTECTS   VM-BASTION
SG-RULE-BASTION-SSH   PART_OF SG-BASTION
SG-RULE-BASTION-ICMP  PART_OF SG-BASTION
SG-RULE-BASTION-SSH   USES    TFVAR-ALLOWED-ADMIN-CIDR
SG-PRIVATE-VMS    PROTECTS   VM-FULL-STACK-JS · VM-LMS-OPENEDX · VM-ODOO-SERVER · VM-JAVA-JS
SG-RULE-VM-SSH-FROM-BASTION  PART_OF SG-PRIVATE-VMS
SG-RULE-VM-ICMP-FROM-BASTION PART_OF SG-PRIVATE-VMS
SG-RULE-VM-SSH-FROM-BASTION  DEPENDS_ON SG-BASTION     (remote_group_id)
SG-RULE-VM-ICMP-FROM-BASTION DEPENDS_ON SG-BASTION     (remote_group_id)
SG-ASSOC-PILOT-VMS  USES     SG-PRIVATE-VMS
SG-BASTION        IMPLEMENTS PRIN-MIN-EXPOSURE
SG-PRIVATE-VMS    IMPLEMENTS PRIN-SINGLE-ENTRY
DEC-008           IMPLEMENTS PRIN-LEAST-PRIVILEGE
FW-ENFORCE-SG     SUPERSEDES DEC-004
```

---

## Decisions (canonical text in [decisions.md](decisions.md))

- `DEC-004` — `enforce = false`: keep legacy SGs during pilot (non-destructive).
- `DEC-006` — agent forwarding disabled on the bastion sshd (host-level, complements SGs).
- `DEC-007` — single entry point: no other public ingress exists or may be added casually.
- `DEC-008` — SG-to-SG referencing instead of CIDRs for internal SSH.

---

## Terraform Knowledge

- File: `security-groups.tf` — 2 `openstack_networking_secgroup_v2` + 4
  `openstack_networking_secgroup_rule_v2` resources; one rule uses `for_each` over
  `TFVAR-ALLOWED-ADMIN-CIDR`.
- `delete_default_rules = false` on both SGs → default egress (any) remains.
- DAG: `SG-BASTION` → `SG-RULE-BASTION-*` and → `SG-RULE-VM-*` (remote_group reference);
  `SG-PRIVATE-VMS` → its rules; `SG-ASSOC-PILOT-VMS` depends on `SG-PRIVATE-VMS`.
- Changing `allowed_admin_cidrs` = in-place rule add/remove (no VM impact).
- Changing SG names = recreation of SGs → drops protection; treat names as stable API.

---

## Infrastructure Workflow

1. `terraform plan` — verify only expected rule diffs (count matches CIDR list).
2. `terraform apply`.
3. `VAL-SG-AUDIT` → `VAL-SSH-BASTION` → `VAL-SSH-JUMP` → `VAL-ICMP-PRIVATE`
   (full ladder in [operations.md](operations.md)).

---

## Validation

- `VAL-SG-AUDIT`:
  `openstack security group rule list sg-bastion-nawel-test`;
  `openstack security group rule list sg-private-vms-via-bastion-test`;
  `openstack port show <vm-port-id> -c security_group_ids`.
- Negative test (required): direct `ssh ubuntu@192.168.100.87` from laptop **must fail**;
  `ssh -J ubuntu@<fip> ubuntu@192.168.100.87` **must succeed** (`VAL-SSH-JUMP`).

---

## Operational Procedures

- Change who may administer: `OP-CHANGE-ADMIN-CIDR`.
- Bring a VM under this model: `OP-ATTACH-TO-BASTION`.
- Post-pilot hardening (future): `FW-ENFORCE-SG` — flip `enforce` to `true` (or rebuild
  ports with only `SG-PRIVATE-VMS`) so legacy SGs no longer bypass the model.
- Full runbook: [operations.md](operations.md).

---

## Future Roadmap

- 80/443 ingress on `SG-BASTION` when `RP-NGINX` lands (`FW-REVERSE-PROXY`, `FW-HTTPS`).
- Egress scoping (currently default allow-any).
- `FW-ENFORCE-SG` to close the `DEC-004` temporary gap.
- Security-group naming/labels per role if MERN onboarding (`FW-MERN-ONBOARDING`)
  warrants separate SGs.

---

## AI Retrieval Optimization

- **Keywords:** security group, sg-bastion-nawel-test, sg-private-vms-via-bastion-test, remote_group_id, ingress, SSH 22, ICMP, CIDR allowlist, allowed_admin_cidrs, enforce false, zero trust, least privilege, port security
- **Tags:** #security #security-groups #firewall #trust-boundary #neutron
- **Related Nodes:** `VM-BASTION`, `NET-PRIVATE`, `SG-ASSOC-PILOT-VMS`, `SSH-PROXYJUMP`, `TFVAR-ALLOWED-ADMIN-CIDR`
- **Parent Nodes:** `PRIN-MIN-EXPOSURE`, `PRIN-SINGLE-ENTRY`, `PRIN-LEAST-PRIVILEGE`
- **Child Nodes:** `SG-BASTION`, `SG-PRIVATE-VMS`, four `SG-RULE-*` nodes
- **Cross References:** [vm-integration.md](vm-integration.md), [ssh-workflows.md](ssh-workflows.md), [decisions.md](decisions.md), [operations.md](operations.md)
- **Aliases:** groupes de sécurité (fr), firewall rules, Neutron SGs, access policy
- **Infrastructure Layer:** SG attachments on ports
- **Networking Layer:** ICMP diagnostics plane
- **Security Layer:** all nodes in this document
- **Terraform Layer:** `security-groups.tf`, `existing-vms.tf`
- **Operational Layer:** `OP-CHANGE-ADMIN-CIDR`, `VAL-SG-AUDIT`, `FW-ENFORCE-SG`
