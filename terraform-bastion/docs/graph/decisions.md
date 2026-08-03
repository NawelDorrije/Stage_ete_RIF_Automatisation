# Feature: Architectural Decisions & Design Principles

> Home document for: `DEC-001`…`DEC-012`, `PRIN-SINGLE-ENTRY`, `PRIN-MIN-EXPOSURE`,
> `PRIN-LEAST-PRIVILEGE`, `PRIN-IAC`, `PRIN-NON-DESTRUCTIVE-TESTING`

Every "why" in the project is answered here. Each decision lists Reason, Advantages,
Tradeoffs, and Alternatives considered, plus its graph edges.

---

## Overview

- **Purpose:** Preserve rationale so future agents/operators don't re-litigate settled
  questions or undo non-obvious safeguards (e.g. commented-out resources are
  *deliberate*, not forgotten).
- **Context:** Migration of legacy manually-built infrastructure to IaC under a
  test-first constraint.
- **Problem solved:** Institutional memory; decisions outlive the internship context
  in which they were made.

---

## Design Principles

### `PRIN-SINGLE-ENTRY` — One controlled entry point

- **Statement:** All administrative access to the private network enters through one
  hardened, auditable host (`VM-BASTION`).
- **Enforced by:** `DEC-007`, `SG-PRIVATE-VMS` (`IMPLEMENTS` edge E048), `DEC-002`.
- **Children:** `SSH-PROXYJUMP`, `FW-REVERSE-PROXY` (extends the principle to HTTP).

### `PRIN-MIN-EXPOSURE` — Minimal public attack surface

- **Statement:** The only public-facing resource is one Floating IP with one open port
  (SSH/22) restricted to named admin CIDRs.
- **Enforced by:** `DEC-001` (only one FIP), `SG-BASTION` (E047), `DEC-006`.

### `PRIN-LEAST-PRIVILEGE` — Smallest viable scope

- **Statement:** Rules reference identity (SG membership) rather than addresses;
  CIDRs are `/32`; host sshd disables everything not needed.
- **Enforced by:** `DEC-008`, `DEC-006`, `INFRA-CLOUDINIT`.

### `PRIN-IAC` — Everything through code

- **Statement:** All mutations flow through Terraform or Ansible under version control;
  manual cloud changes are defects.
- **Enforced by:** `DEC-009`, `DEC-011`; measured by `OP-*` procedures.

### `PRIN-NON-DESTRUCTIVE-TESTING` — Never break the legacy during migration

- **Statement:** Automation wraps pre-existing infrastructure additively until each
  layer is validated.
- **Enforced by:** `DEC-001`, `DEC-004`, `DEC-005`.

---

## Decisions

### `DEC-001` — Reuse a pre-existing Floating IP; Terraform must not create one

- **Decision:** The bastion's public IP was allocated manually beforehand. The
  `openstack_networking_floatingip_v2.bastion` resource is kept **commented out**
  in `bastion.tf`; only an `openstack_networking_floatingip_associate_v2` is managed.
- **Reason:** The FIP is a scarce, externally-known address; losing it to a
  `destroy`/recreate cycle would break every documented access path.
- **Advantages:** FIP survives any Terraform lifecycle event; no risk of address
  churn; association remains fully IaC.
- **Tradeoffs:** FIP itself is invisible to `plan` (external drift possible);
  `floating_ip_subnet_id` became an orphan required variable (`ISSUE-ORPHAN-FIP-SUBNET-VAR`).
- **Alternatives considered:** fully managed FIP (commented code — rejected for now,
  revisit via import later); DNS-based indirection (deferred to `FW-DOMAIN-DNS`).
- **Edges:** `RELATED_TO INFRA-FIP`; `IMPLEMENTS PRIN-NON-DESTRUCTIVE-TESTING`;
  `RELATED_TO ISSUE-ORPHAN-FIP-SUBNET-VAR`.
- **Files:** `bastion.tf` lines 74–89.

### `DEC-002` — `prevent_destroy` on bastion instance and port

- **Decision:** Both `openstack_compute_instance_v2.bastion` and
  `openstack_networking_port_v2.bastion` carry `lifecycle { prevent_destroy = true }`.
- **Reason:** The bastion is the only way in; an accidental destroy locks everyone out
  and orphans the FIP mapping.
- **Advantages:** `apply` physically cannot remove the access layer.
- **Tradeoffs:** legitimate teardown/rebuild needs the two-phase lifecycle edit
  (documented in `OP-ROLLBACK`).
- **Alternatives considered:** rely on process discipline (rejected — humans err);
  `terraform taint` workflows (insufficient — destroy still possible).
- **Edges:** `RELATED_TO VM-BASTION`; `RELATED_TO INFRA-BASTION-PORT`;
  `IMPLEMENTS PRIN-SINGLE-ENTRY`.
- **Files:** `bastion.tf` lines 14–16, 65–67.

### `DEC-003` — `ignore_changes = [user_data]`; post-boot changes go through Ansible

- **Decision:** The instance ignores `user_data` drift after creation.
- **Reason:** Cloud-init runs only at first boot; without `ignore_changes`, any
  cloud-config edit would force instance **replacement** — unacceptable combined with
  `DEC-002`'s intent (and would fight `prevent_destroy` with errors).
- **Advantages:** Stable plans; no accidental rebuilds from hardening edits.
- **Tradeoffs:** **`ISSUE-USERDATA-DRIFT`** — tfvars edits to `admin_ssh_keys` silently
  do nothing; operators must know the Ansible path (`OP-ADD-SSH-KEY`).
- **Alternatives considered:** allow replacement on user_data change (rejected —
  contradicts `DEC-002`); manage keys via `openstack_compute_keypair_v2` only
  (insufficient for multi-admin).
- **Edges:** `RELATED_TO INFRA-CLOUDINIT`; `RELATED_TO ISSUE-USERDATA-DRIFT`;
  `IMPLEMENTS PRIN-IAC`.
- **Files:** `bastion.tf` lines 68–70.

### `DEC-004` — `enforce = false` on the pilot SG association

- **Decision:** `openstack_networking_port_secgroup_associate_v2.tested_vms` attaches
  `SG-PRIVATE-VMS` **additively**; pre-existing SGs on legacy VM ports are preserved.
- **Reason:** During the test phase, stripping legacy SGs could cut off unknown
  existing access paths (the code comment says exactly this: "Conserve les Security
  Groups existants pendant la phase de test").
- **Advantages:** Zero-risk onboarding; trivial rollback (`OP-REMOVE-VM`).
- **Tradeoffs:** The bastion model is **not yet exclusive** — legacy rules may still
  permit non-bastion SSH; closed later by `FW-ENFORCE-SG`.
- **Alternatives considered:** `enforce = true` from day one (rejected — destructive
  unknown unknowns); manual SG edits in Horizon (rejected — violates `PRIN-IAC`).
- **Edges:** `RELATED_TO SG-ASSOC-PILOT-VMS`; `IMPLEMENTS PRIN-NON-DESTRUCTIVE-TESTING`;
  superseded-by: `FW-ENFORCE-SG SUPERSEDES DEC-004` (E121).
- **Files:** `existing-vms.tf` line 11.

### `DEC-005` — Pilot rollout order: Full-Stack-JS + LMS-OpenedX → Odoo + Java-JS → MERN

- **Decision:** Attach two pilot VMs first; only after their validation uncomment
  `odoo_server` and `java_js`; MERN trio stays placeholder.
- **Reason:** Bounded blast radius while proving `SG-ASSOC-PILOT-VMS` semantics on real
  workloads (encoded directly in `terraform.tfvars.example` comments).
- **Advantages:** Early detection of SG/SSH regressions on low-stakes VMs.
- **Tradeoffs:** Multi-step tfvars choreography; phase state lives in comments
  (human-gated, not code-gated).
- **Alternatives considered:** big-bang attach of all VMs (rejected);
  Terraform workspaces per phase (overkill).
- **Edges:** `RELATED_TO SG-ASSOC-PILOT-VMS`; `IMPLEMENTS PRIN-NON-DESTRUCTIVE-TESTING`.
- **Files:** `terraform.tfvars.example` lines 22–33.

### `DEC-006` — ProxyJump only; agent forwarding disabled on the bastion

- **Decision:** sshd on the bastion sets `AllowAgentForwarding no` (plus no X11, no
  tunnels); the sanctioned access pattern is `ssh -J` (`SSH-PROXYJUMP`).
- **Reason:** With agent forwarding, a compromised bastion could abuse admins' loaded
  keys for lateral movement. ProxyJump authenticates end-to-end from the laptop —
  the bastion never holds usable credentials.
- **Advantages:** Bastion compromise ≠ fleet-wide key compromise; clean audit model.
- **Tradeoffs:** Slightly more complex client commands (mitigated by `SSH-CONFIG` and
  `TFOUT-SSH-*` outputs); tools assuming `-A` need reconfiguration.
- **Alternatives considered:** agent forwarding with `AddKeysToAgent` discipline
  (rejected — still exposes the socket); per-VM Floating IPs (rejected — `DEC-007`).
- **Edges:** `RELATED_TO SSH-PROXYJUMP`; `IMPLEMENTS PRIN-LEAST-PRIVILEGE`.
- **Files:** `bastion.tf` (cloud-init sshd config), `ansible/bastion-hardening.yml`.

### `DEC-007` — Single public entry point; internal VMs are SSH-private

- **Decision:** No internal VM gets a Floating IP or public SG rule — now or
  "temporarily". User-facing HTTP exposure will come later through `RP-NGINX`, not
  per-VM public IPs.
- **Reason:** Every public IP is attack surface and cost; one hardened choke point is
  auditable.
- **Advantages:** Minimal surface (`PRIN-MIN-EXPOSURE`); one place to harden/log.
- **Tradeoffs:** Bastion is SPOF for admin access; app users must wait for the
  reverse-proxy phase (`FW-REVERSE-PROXY`).
- **Alternatives considered:** per-VM FIPs (rejected); VPN server instead of SSH
  bastion (future consideration, heavier).
- **Edges:** `IMPLEMENTS PRIN-SINGLE-ENTRY`; `RELATED_TO SG-PRIVATE-VMS`,
  `RELATED_TO RP-NGINX`.
- **Files:** whole-module invariant (no FIP resources except the bastion association).

### `DEC-008` — SG-to-SG referencing (`remote_group_id`) instead of CIDRs

- **Decision:** `SG-RULE-VM-SSH-FROM-BASTION` and `SG-RULE-VM-ICMP-FROM-BASTION`
  authorize **members of `SG-BASTION`**, not `192.168.100.x/32` literals.
- **Reason:** Trust should follow identity, not addressing; the bastion's private IP
  can change without touching any VM rule.
- **Advantages:** Zero rule churn on IP drift; self-documenting intent in
  `openstack security group rule list`.
- **Tradeoffs:** Creates a hard dependency of all VM access on the bastion port
  keeping its SG (documented in `SG-RULE-VM-SSH-FROM-BASTION` risks).
- **Alternatives considered:** CIDR of the bastion's fixed IP (rejected — brittle);
  wide `/24` CIDR (rejected — any VM could SSH to any VM).
- **Edges:** `IMPLEMENTS PRIN-LEAST-PRIVILEGE`; `RELATED_TO SG-BASTION`.
- **Files:** `security-groups.tf` lines 33–49.

### `DEC-009` — Terraform Cloud remote backend

- **Decision:** State lives in Terraform Cloud org `rif-stagiaires`, workspace
  `Nawel-Bastion-Test` (`cloud {}` block); no local state files.
- **Reason:** Shared internship project — state locking, history, and no
  `*.tfstate` on laptops.
- **Advantages:** Locking prevents concurrent applies; state (with secrets) stays off
  disk; run history in TFC UI.
- **Tradeoffs:** Hardcoded workspace name = one environment per code copy;
  `terraform login` required; offline work impossible.
- **Alternatives considered:** local state (rejected — sharing/locking);
  OpenStack Swift backend (viable alternative, not chosen).
- **Edges:** `RELATED_TO INFRA-TFCLOUD`; `IMPLEMENTS PRIN-IAC`.
- **Files:** `providers.tf` lines 2–8.

### `DEC-010` — Reuse existing keypair `Full_Stack_JS_key`

- **Decision:** The bastion boots with the pre-existing keypair created for the
  Full-Stack-JS VM (default of `existing_keypair_name`).
- **Reason:** Pragmatism — the key already existed and was held by the operator;
  avoids bootstrapping yet another key during the test phase.
- **Advantages:** Zero setup friction.
- **Tradeoffs:** **`ISSUE-SHARED-KEYPAIR`** — shared blast radius, muddy audit trail.
- **Alternatives considered:** dedicated bastion keypair (the correct end-state —
  pending); Vault-issued SSH certs (`FW-VAULT`).
- **Edges:** `RELATED_TO INFRA-KEYPAIR`; `RELATED_TO ISSUE-SHARED-KEYPAIR`.
- **Files:** `variables.tf` lines 52–55, `bastion.tf` line 23.

### `DEC-011` — Dual hardening path: cloud-init (birth) + Ansible (life)

- **Decision:** `ansible/bastion-hardening.yml` intentionally mirrors the cloud-init
  hardening (same packages, same `99-bastion.conf`, same services).
- **Reason:** `DEC-003` freezes cloud-init after birth; Ansible provides the idempotent
  steady-state path without forcing rebuilds.
- **Advantages:** Bastion is hardened even if Ansible never runs; convergent ops via
  `OP-RUN-ANSIBLE`; playbook doubles as executable documentation.
- **Tradeoffs:** **Mirror discipline required** — a hardening change must touch both
  files or they drift (risk recorded in `INFRA-ANSIBLE`).
- **Alternatives considered:** cloud-init only (rejected — immutable);
  Ansible-only with plain image (rejected — unhardened window at boot).
- **Edges:** `RELATED_TO INFRA-ANSIBLE`; `IMPLEMENTS PRIN-IAC`.
- **Files:** `ansible/bastion-hardening.yml`, `bastion.tf` cloud-init block.

### `DEC-012` — Hardcoded localhost `endpoint_overrides` in the provider

- **Decision:** All OpenStack service endpoints are pinned to `127.0.0.1` ports in
  `providers.tf` rather than discovered from the catalog.
- **Reason:** The all-in-one cloud (RegionOne, DevStack-style) advertises endpoints
  that don't match how the operator reaches them; overrides make runs deterministic.
- **Advantages:** No catalog surprises; works on the cloud host with zero config.
- **Tradeoffs:** **`ISSUE-LOCALHOST-ENDPOINTS`** — runs require being on the host or
  an SSH multi-port forward; blocks naive CI (`FW-CICD`).
- **Alternatives considered:** fix the cloud's advertised catalog (out of scope —
  shared training cloud); clouds.yaml + env vars (candidate future refactor).
- **Edges:** `RELATED_TO INFRA-OPENSTACK-ENDPOINTS`; `RELATED_TO ISSUE-LOCALHOST-ENDPOINTS`.
- **Files:** `providers.tf` lines 27–36.

---

## Graph Relationships (local view)

```
DEC-001 IMPLEMENTS PRIN-NON-DESTRUCTIVE-TESTING · RELATED_TO INFRA-FIP · RELATED_TO ISSUE-ORPHAN-FIP-SUBNET-VAR
DEC-002 IMPLEMENTS PRIN-SINGLE-ENTRY            · RELATED_TO VM-BASTION · RELATED_TO INFRA-BASTION-PORT
DEC-003 IMPLEMENTS PRIN-IAC                     · RELATED_TO INFRA-CLOUDINIT · RELATED_TO ISSUE-USERDATA-DRIFT
DEC-004 IMPLEMENTS PRIN-NON-DESTRUCTIVE-TESTING · RELATED_TO SG-ASSOC-PILOT-VMS
DEC-005 IMPLEMENTS PRIN-NON-DESTRUCTIVE-TESTING · RELATED_TO SG-ASSOC-PILOT-VMS
DEC-006 IMPLEMENTS PRIN-LEAST-PRIVILEGE         · RELATED_TO SSH-PROXYJUMP
DEC-007 IMPLEMENTS PRIN-SINGLE-ENTRY            · RELATED_TO SG-PRIVATE-VMS · RELATED_TO RP-NGINX
DEC-008 IMPLEMENTS PRIN-LEAST-PRIVILEGE         · RELATED_TO SG-BASTION
DEC-009 IMPLEMENTS PRIN-IAC                     · RELATED_TO INFRA-TFCLOUD
DEC-010 RELATED_TO  INFRA-KEYPAIR · RELATED_TO ISSUE-SHARED-KEYPAIR
DEC-011 IMPLEMENTS PRIN-IAC       · RELATED_TO INFRA-ANSIBLE
DEC-012 RELATED_TO  INFRA-OPENSTACK-ENDPOINTS · RELATED_TO ISSUE-LOCALHOST-ENDPOINTS
FW-ENFORCE-SG SUPERSEDES DEC-004
```

---

## Terraform Knowledge / Workflow / Validation / Operational Procedures

Not feature-specific here — each decision's *Files* line points to the enforcing
code; procedures live in [operations.md](operations.md); validation of decision
invariants happens in the ladder (`VAL-SG-AUDIT` for `DEC-004/008`, `VAL-HARDENING`
for `DEC-006/011`, plan review for `DEC-001/002/003`).

---

## Future Roadmap

Decisions explicitly designed to be revisited:

| Decision | Revisit trigger | Successor node |
|---|---|---|
| `DEC-004` | pilot phases 1–2 validated | `FW-ENFORCE-SG` |
| `DEC-010` | security hardening phase | `FW-VAULT` / dedicated keypair |
| `DEC-012` | CI adoption | `FW-CICD` (+ endpoint refactor) |
| `DEC-001` | if FIP import is accepted | managed `openstack_networking_floatingip_v2` |
| `DEC-005` | MERN VMs arrive | `FW-MERN-ONBOARDING` |

---

## AI Retrieval Optimization

- **Keywords:** ADR, architecture decision record, rationale, why, prevent_destroy, ignore_changes, enforce false, remote_group_id, ProxyJump no agent forwarding, terraform cloud backend, commented floating ip resource, pilot rollout, design principles, tradeoffs, alternatives considered
- **Tags:** #decisions #adr #principles #rationale
- **Related Nodes:** all nodes — decisions are the connective tissue of the graph
- **Parent Nodes:** none (principles are roots)
- **Child Nodes:** `DEC-001..012`, `PRIN-*`
- **Cross References:** every feature document (each links its governing decisions)
- **Aliases:** décisions d'architecture (fr), ADRs, design rationale
- **Infrastructure Layer:** `DEC-001`, `DEC-007`
- **Networking Layer:** `DEC-001`, `DEC-012`
- **Security Layer:** `DEC-006`, `DEC-008`, `DEC-010`
- **Terraform Layer:** `DEC-002`, `DEC-003`, `DEC-004`, `DEC-009`
- **Operational Layer:** `DEC-005`, `DEC-011`
