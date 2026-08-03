# Feature: Existing VM Integration (Pilot Rollout)

> Home document for: `VM-FULL-STACK-JS`, `VM-LMS-OPENEDX`, `VM-ODOO-SERVER`,
> `VM-JAVA-JS`, `SG-ASSOC-PILOT-VMS`, `ISSUE-MANUAL-PORT-ID`

---

## Overview

- **Purpose:** Bring pre-existing, manually-created OpenStack VMs under the bastion
  security model **without touching the VMs themselves** — no rebuild, no agent, no
  downtime; only their Neutron ports gain an additional security group.
- **Context:** Four training VMs (LMS-OpenedX, Odoo, Full-Stack-JS, Java-JS) existed
  before automation. Terraform must not adopt/destroy them (`PRIN-NON-DESTRUCTIVE-TESTING`);
  it only attaches `SG-PRIVATE-VMS` to their existing ports.
- **Problem solved:** Legacy VMs keep working exactly as before while gaining
  bastion-gated SSH; rollback = one `terraform apply` after removing a map entry.
- **Why it exists:** This is the *migration* mechanism of the project: infrastructure
  as code wraps reality instead of replacing it.

---

## Architecture

### Mechanism

`TFVAR-EXISTING-VM-PORTS` (map: logical name → Neutron **Port ID**) drives
`openstack_networking_port_secgroup_associate_v2.tested_vms` (`existing-vms.tf`)
with `for_each`. Each association adds `SG-PRIVATE-VMS` to that port with
`enforce = false` (`DEC-004`) — pre-existing SGs on the port are preserved.

```
TFVAR-EXISTING-VM-PORTS ──for_each──▶ SG-ASSOC-PILOT-VMS ──adds──▶ SG-PRIVATE-VMS
        │                                                              │ PROTECTS
        ▼                                                              ▼
   Neutron port of VM-* ◄──────────────────── attached ─────────── VM-*
```

### Rollout phases (`DEC-005`)

| Phase | VMs | State in `terraform.tfvars.example` |
|---|---|---|
| 1 — Pilot | `VM-FULL-STACK-JS` (.87), `VM-LMS-OPENEDX` (.55) | active entries |
| 2 — After pilot validation | `VM-ODOO-SERVER` (.91), `VM-JAVA-JS` (.149) | commented, "uncomment only after validating the two pilot VMs" |
| 3 — Future | `VM-MERN-FRONTEND`, `VM-MERN-BACKEND`, `VM-MERN-MONGODB` | commented placeholders (→ `FW-MERN-ONBOARDING`) |

### Security boundaries

Each associated VM moves from "SSH path = whatever legacy SGs allowed" to
"SSH **also** possible via bastion". Because `enforce = false`, legacy paths remain
until `FW-ENFORCE-SG` — the pilot phase is deliberately additive, not yet exclusive.

---

## Graph Nodes

### `VM-FULL-STACK-JS` — Full-Stack-JS (`192.168.100.87`)

- **Type:** VM · **Layer:** Infrastructure
- **Description:** Pre-existing training VM (full-stack JavaScript workload). Its
  keypair name lives on in `INFRA-KEYPAIR` (`Full_Stack_JS_key`) — evidence it was the
  project's first VM. Pilot phase 1.
- **Purpose:** Workload host; pilot member validating the bastion model.
- **Dependencies:** `NET-PRIVATE` (fixed IP .87).
- **Related Components:** `SG-ASSOC-PILOT-VMS` (configures its port),
  `SG-PRIVATE-VMS` (protects it), `TFOUT-SSH-FULL-STACK-JS`, `INFRA-KEYPAIR` (namesake).
- **Files involved:** `terraform.tfvars.example` (`full_stack_js` entry), `outputs.tf`.
- **Commands:** `ssh -J ubuntu@<fip> ubuntu@192.168.100.87`;
  `openstack port list --server <server-name>`.
- **Validation procedure:** `VAL-SSH-JUMP` + `VAL-ICMP-PRIVATE` from bastion.
- **Risks:** legacy SGs still apply during pilot (`DEC-004`); hardcoded IP in outputs
  (`ISSUE-HARDCODED-IPS`).
- **Future improvements:** full Terraform adoption (import) post-pilot; monitoring
  (`FW-PROMETHEUS`).

### `VM-LMS-OPENEDX` — LMS-OpenedX (`192.168.100.55`)

- **Type:** VM · **Layer:** Infrastructure
- **Description:** Pre-existing Open edX LMS training VM. Pilot phase 1.
- **Purpose:** Workload host (LMS); second pilot member.
- **Dependencies:** `NET-PRIVATE` (fixed IP .55).
- **Related Components:** `SG-ASSOC-PILOT-VMS`, `SG-PRIVATE-VMS`, `TFOUT-SSH-LMS-OPENEDX`.
- **Files involved:** `terraform.tfvars.example` (`lms_openedx` entry), `outputs.tf`.
- **Commands:** `ssh -J ubuntu@<fip> ubuntu@192.168.100.55`.
- **Validation procedure:** `VAL-SSH-JUMP` + `VAL-ICMP-PRIVATE`.
- **Risks:** same pilot-phase risks as `VM-FULL-STACK-JS`; Open edX services need HTTP
  access later → `FW-REVERSE-PROXY` is its public path (no FIP per VM, `DEC-007`).
- **Future improvements:** reverse-proxy vhost `lms.<domain>` (`RP-NGINX` + `FW-DOMAIN-DNS`).

### `VM-ODOO-SERVER` — Odoo Server (`192.168.100.91`)

- **Type:** VM · **Layer:** Infrastructure
- **Description:** Pre-existing Odoo ERP training VM. Phase 2 — attach only after the
  two pilot VMs validate (`DEC-005`).
- **Purpose:** Workload host (ERP).
- **Dependencies:** `NET-PRIVATE` (fixed IP .91).
- **Related Components:** `SG-PRIVATE-VMS`, `TFOUT-SSH-ODOO-SERVER`.
- **Files involved:** `terraform.tfvars.example` (commented `odoo_server`), `outputs.tf`.
- **Commands:** `ssh -J ubuntu@<fip> ubuntu@192.168.100.91`.
- **Validation procedure:** same as pilot VMs, applied during phase 2.
- **Risks:** Odoo's web UI (8069) will need `RP-NGINX` for users; direct exposure is
  against `DEC-007`.
- **Future improvements:** vhost `odoo.<domain>`; HTTPS via `FW-HTTPS`.

### `VM-JAVA-JS` — Java-JS (`192.168.100.149`)

- **Type:** VM · **Layer:** Infrastructure
- **Description:** Pre-existing Java/JavaScript training VM. Phase 2 (`DEC-005`).
- **Purpose:** Workload host.
- **Dependencies:** `NET-PRIVATE` (fixed IP .149).
- **Related Components:** `SG-PRIVATE-VMS`, `TFOUT-SSH-JAVA-JS`.
- **Files involved:** `terraform.tfvars.example` (commented `java_js`), `outputs.tf`.
- **Commands:** `ssh -J ubuntu@<fip> ubuntu@192.168.100.149`.
- **Validation procedure:** same as pilot VMs, applied during phase 2.
- **Risks:** standard pilot risks.
- **Future improvements:** import into Terraform; monitoring.

### `SG-ASSOC-PILOT-VMS` — Port↔SG association on existing VMs

- **Type:** Security Group (association) · **Layer:** Security + Terraform
- **Description:** `openstack_networking_port_secgroup_associate_v2.tested_vms`
  (`existing-vms.tf`). `for_each = var.existing_vm_ports`; `port_id = each.value`;
  attaches `SG-PRIVATE-VMS`; **`enforce = false`** keeps all pre-existing SGs on the
  port (comment in code: "Conserve les Security Groups existants pendant la phase de test").
- **Purpose:** The single, reversible touchpoint between Terraform and legacy VMs.
- **Dependencies:** `SG-PRIVATE-VMS`, `TFVAR-EXISTING-VM-PORTS`; operationally
  `OP-RETRIEVE-PORT-ID` (map values come from Horizon/CLI).
- **Related Components:** `DEC-004`, `DEC-005`, `ISSUE-MANUAL-PORT-ID`, `FW-ENFORCE-SG`,
  `OP-ATTACH-TO-BASTION`, `OP-REMOVE-VM`.
- **Files involved:** `existing-vms.tf`, `variables.tf` (`existing_vm_ports`), tfvars.
- **Commands:** `terraform state list | grep tested_vms`;
  `openstack port show <port-id> -c security_group_ids`.
- **Validation procedure:** `VAL-SG-AUDIT` — each pilot port lists `SG-PRIVATE-VMS`
  **plus** its legacy SGs; `VAL-SSH-JUMP` succeeds per VM.
- **Risks:** wrong Port ID in the map = protecting the wrong port (no error from
  OpenStack — the ID exists, it's just not your VM's); always cross-check IP
  (`OP-RETRIEVE-PORT-ID` step 3). Removing the last map entry with an empty map
  destroys all associations — expected, but run `plan` first.
- **Future improvements:** `FW-ENFORCE-SG` (`enforce = true` or rebuilt ports) and
  `FW-PORT-AUTODISCOVERY` (data-source lookups by fixed IP instead of pasted IDs).

### `ISSUE-MANUAL-PORT-ID` — Port IDs are pasted by hand

- **Type:** Known Issue · **Layer:** Operational
- **Description:** `existing_vm_ports` values are raw Neutron Port UUIDs that a human
  must copy out of Horizon (or CLI) into tfvars. Nothing validates that the UUID
  belongs to the intended VM.
- **Impact:** onboarding toil per VM (`OP-RETRIEVE-PORT-ID`); risk of silent
  mis-association (see `SG-ASSOC-PILOT-VMS` risks).
- **Files involved:** `terraform.tfvars.example`, `existing-vms.tf`.
- **Mitigation:** verification step inside `OP-RETRIEVE-PORT-ID` (match port IP to the
  VM's known private IP before applying).
- **Related:** `OP-RETRIEVE-PORT-ID`, `FW-PORT-AUTODISCOVERY` (supersedes it).

---

## Graph Relationships (local view)

```
SG-ASSOC-PILOT-VMS  USES       TFVAR-EXISTING-VM-PORTS
SG-ASSOC-PILOT-VMS  USES       SG-PRIVATE-VMS
SG-ASSOC-PILOT-VMS  CONFIGURES VM-FULL-STACK-JS · VM-LMS-OPENEDX        (phase 1)
SG-ASSOC-PILOT-VMS  CONFIGURES VM-ODOO-SERVER · VM-JAVA-JS              (phase 2)
SG-PRIVATE-VMS      PROTECTS   all four VM-*
VM-*                DEPENDS_ON NET-PRIVATE
DEC-005             RELATED_TO SG-ASSOC-PILOT-VMS
DEC-004             RELATED_TO SG-ASSOC-PILOT-VMS
ISSUE-MANUAL-PORT-ID RELATED_TO TFVAR-EXISTING-VM-PORTS
FW-PORT-AUTODISCOVERY SUPERSEDES ISSUE-MANUAL-PORT-ID
FW-ENFORCE-SG       SUPERSEDES DEC-004
FW-MERN-ONBOARDING  DEPENDS_ON SG-ASSOC-PILOT-VMS
OP-ATTACH-TO-BASTION CONFIGURES SG-ASSOC-PILOT-VMS
OP-REMOVE-VM        CONFIGURES SG-ASSOC-PILOT-VMS
```

---

## Decisions (canonical text in [decisions.md](decisions.md))

- `DEC-004` — additive association (`enforce = false`) during the test phase.
- `DEC-005` — phased rollout 2 VMs → 2 VMs → MERN, gated on validation.
- `DEC-007` — no VM receives its own Floating IP; user traffic will come later via `RP-NGINX`.
- `DEC-008` — the protection granted to VMs is SG-to-SG, surviving IP drift.

---

## Terraform Knowledge

- `existing-vms.tf`: one resource, `for_each` over the map; map key (e.g.
  `full_stack_js`) becomes the state address suffix
  `…tested_vms["full_stack_js"]` — **keys are stable identifiers; renaming a key
  destroys+recreates the association** (harmless but noisy).
- `variables.tf`: `existing_vm_ports` is `map(string)`, no default — required.
- tfvars lifecycle: add/uncomment an entry → `plan` shows `+1` association → `apply` →
  validate → proceed to next phase. Removing an entry destroys only that association.

---

## Infrastructure Workflow

1. `OP-RETRIEVE-PORT-ID` for the target VM (Horizon or CLI) → Port UUID.
2. Add `logical_name = "PORT_UUID"` to `existing_vm_ports` in `terraform.tfvars`.
3. `DEPLOY-PLAN` — expect exactly one `openstack_networking_port_secgroup_associate_v2`
   to be created. Anything else in the plan = stop and investigate.
4. `DEPLOY-APPLY`.
5. `OP-VERIFY-ACCESS`: `VAL-SG-AUDIT` → `VAL-SSH-JUMP` → `VAL-ICMP-PRIVATE`.
6. Only after phases 1–2 are green: consider `FW-ENFORCE-SG`.

---

## Validation

- Per VM after association:
  `openstack port show <port-id> -c security_group_ids` contains `SG-PRIVATE-VMS`;
  `ssh -J ubuntu@<fip> ubuntu@<vm-ip> hostname` returns the VM's name;
  from bastion `ping -c3 <vm-ip>`.
- Fleet check: `terraform state list | grep port_secgroup_associate` matches the
  tfvars map keys.

---

## Operational Procedures

Canonical runbook (→ See: [operations.md](operations.md)):

- `OP-ADD-VM` — create/select the VM on `NET-PRIVATE` first.
- `OP-RETRIEVE-PORT-ID` — Horizon path **and** CLI path, with IP cross-check.
- `OP-ATTACH-TO-BASTION` — tfvars edit + apply.
- `OP-VERIFY-ACCESS` — the three-step validation above.
- `OP-REMOVE-VM` — delete map entry + apply (association only; VM untouched).

---

## Future Roadmap

- `FW-MERN-ONBOARDING` — `VM-MERN-FRONTEND` / `VM-MERN-BACKEND` / `VM-MERN-MONGODB`
  placeholders already exist in `terraform.tfvars.example`.
- `FW-ENFORCE-SG` — graduate from additive to exclusive SG control post-pilot.
- `FW-PORT-AUTODISCOVERY` — replace pasted UUIDs with
  `data "openstack_networking_port_ids_v2"` filtered by fixed IP.
- Full VM import into Terraform (compute instances as managed resources) — long-term.

---

## AI Retrieval Optimization

- **Keywords:** existing VMs, legacy VMs, pilot VMs, port_secgroup_associate, enforce false, Neutron port ID, Horizon port, rollout phases, LMS-OpenedX, Odoo, Full-Stack-JS, Java-JS, MERN, 192.168.100.55, 192.168.100.87, 192.168.100.91, 192.168.100.149
- **Tags:** #migration #vms #pilot #rollout #security-groups #onboarding
- **Related Nodes:** `SG-PRIVATE-VMS`, `SSH-PROXYJUMP`, `NET-PRIVATE`, `TFVAR-EXISTING-VM-PORTS`, `TFOUT-SSH-*`
- **Parent Nodes:** `DEC-005`, `PRIN-NON-DESTRUCTIVE-TESTING`
- **Child Nodes:** four `VM-*`, `SG-ASSOC-PILOT-VMS`, `ISSUE-MANUAL-PORT-ID`
- **Cross References:** [security-model.md](security-model.md), [operations.md](operations.md), [future-roadmap.md](future-roadmap.md), [decisions.md](decisions.md)
- **Aliases:** VMs existantes (fr), legacy workload onboarding, bastion pilot phase
- **Infrastructure Layer:** `VM-*`
- **Networking Layer:** Neutron ports of the VMs
- **Security Layer:** `SG-ASSOC-PILOT-VMS`, `SG-PRIVATE-VMS`
- **Terraform Layer:** `existing-vms.tf`, `TFVAR-EXISTING-VM-PORTS`
- **Operational Layer:** `OP-*`, `ISSUE-MANUAL-PORT-ID`, phase gating
