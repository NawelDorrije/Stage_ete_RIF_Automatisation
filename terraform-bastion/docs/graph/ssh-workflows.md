# Feature: SSH Access Workflows

> Home document for: `ACTOR-ADMINS`, `SSH-DIRECT-BASTION`, `SSH-PROXYJUMP`,
> `SSH-CONFIG`, `SSH-SCP-VIA-JUMP`

---

## Overview

- **Purpose:** Define exactly how humans reach machines: one public SSH hop to the
  bastion, then ProxyJump hops to internal VMs. No other path is sanctioned.
- **Context:** Internal VMs have no Floating IPs; their ports accept SSH only from
  `SG-BASTION`. Agent forwarding is disabled on the bastion (`DEC-006`), which dictates
  the client-side workflow (`-J`, not `-A`).
- **Problem solved:** Gives every admin a copy-pasteable, auditable access pattern and
  makes "how do I reach X?" a graph lookup (`TFOUT-SSH-*`), not tribal knowledge.
- **Why it exists:** Operationalization of `PRIN-SINGLE-ENTRY`; every connection is
  funneled through the hardened, fail2ban-protected host.

---

## Architecture

### Flows

```
(1) SSH-DIRECT-BASTION
    laptop ──ssh──> INFRA-FIP:22 ──> VM-BASTION            [administration of the bastion itself]

(2) SSH-PROXYJUMP
    laptop ──ssh──> VM-BASTION ──ssh──> VM-*:22            [administration of internal VMs]
    authentication happens TWICE, both times from the laptop's local keys
    (bastion never holds user keys — AllowAgentForwarding no, DEC-006)

(3) SSH-SCP-VIA-JUMP
    scp -o ProxyJump … / rsync -e 'ssh -J …'               [file transfer through the same path]
```

### Key material map

| Where | Key | Injected by |
|---|---|---|
| laptop → bastion | private key of `INFRA-KEYPAIR` (`Full_Stack_JS_key`) | Nova at boot |
| laptop → bastion | any key in `TFVAR-ADMIN-SSH-KEYS` | `INFRA-CLOUDINIT` (first boot only — `ISSUE-USERDATA-DRIFT`) |
| laptop → each VM | that VM's own pre-existing keypair | manual (pre-automation era) |

### Security boundaries

- All public SSH terminates at `SG-BASTION` (CIDR allowlist).
- All internal SSH originates from a port tagged `SG-BASTION` (`DEC-008`).
- Bastion sshd: no passwords, no root, no agent forwarding, no tunnels/X11,
  `MaxAuthTries 3` (see `INFRA-CLOUDINIT`).

---

## Graph Nodes

### `ACTOR-ADMINS` — Administrators / Developers

- **Type:** Actor · **Layer:** Operational
- **Description:** Human operators (interns/administrators of the training platform)
  whose public IPs are enumerated in `TFVAR-ALLOWED-ADMIN-CIDR` and whose public keys
  live in `TFVAR-ADMIN-SSH-KEYS` and/or the boot keypair.
- **Purpose:** The only principals authorized to originate SSH into the graph.
- **Dependencies:** `SSH-DIRECT-BASTION`, `SSH-PROXYJUMP`.
- **Related Components:** `OP-CHANGE-ADMIN-CIDR`, `OP-ADD-SSH-KEY`.
- **Files involved:** `terraform.tfvars(.example)` (CIDRs, keys).
- **Commands:** all commands in this document.
- **Validation procedure:** `VAL-SSH-BASTION`, `VAL-SSH-JUMP`.
- **Risks:** roaming admins (changing IPs) churn the CIDR list; shared keypair
  (`ISSUE-SHARED-KEYPAIR`) blurs per-person audit trails — use distinct keys in
  `admin_ssh_keys` for accountability.
- **Future improvements:** per-admin keypairs + Vault-signed SSH certificates (`FW-VAULT`).

### `SSH-DIRECT-BASTION` — `ssh ubuntu@<floating-ip>`

- **Type:** SSH Workflow · **Layer:** Operational
- **Description:** Direct administration of the bastion through `INFRA-FIP`.
  Canonical command generated as `TFOUT-SSH-BASTION`.
- **Purpose:** Bastion self-administration, hardening checks, Ansible runs, pivot point
  for manual diagnostics.
- **Dependencies:** `INFRA-FIP-ASSOC`, `SG-RULE-BASTION-SSH`, `INFRA-KEYPAIR`.
- **Related Components:** `TFOUT-SSH-BASTION`, `VAL-SSH-BASTION`, `OP-RUN-ANSIBLE`.
- **Files involved:** `outputs.tf` (`ssh_bastion`).
- **Commands:** `ssh ubuntu@<floating-ip>`; with explicit key:
  `ssh -i ~/.ssh/<key> ubuntu@<floating-ip>`.
- **Validation procedure:** login succeeds; `whoami` → `ubuntu`; `sudo -n true` works
  (passwordless sudo on Ubuntu cloud images).
- **Risks:** lockout if `allowed_admin_cidrs` no longer contains your current IP
  (fix: `OP-CHANGE-ADMIN-CIDR`).
- **Future improvements:** `SSH-CONFIG` alias `bastion`.

### `SSH-PROXYJUMP` — `ssh -J ubuntu@<fip> ubuntu@<vm-private-ip>`

- **Type:** SSH Workflow · **Layer:** Operational
- **Description:** The standard way to reach any internal VM. OpenSSH ≥ 7.3 `-J`
  (ProxyJump) multiplexes through the bastion; authentication to both hops uses the
  **local** laptop keys. Canonical commands generated as `TFOUT-SSH-LMS-OPENEDX`,
  `TFOUT-SSH-ODOO-SERVER`, `TFOUT-SSH-FULL-STACK-JS`, `TFOUT-SSH-JAVA-JS`.
- **Purpose:** Reach VMs that have no public address, under bastion-only SG trust.
- **Dependencies:** `SSH-DIRECT-BASTION`, `SG-RULE-VM-SSH-FROM-BASTION`, target VM's
  own keypair available locally.
- **Related Components:** `DEC-006` (why `-J` and not agent forwarding),
  `VAL-SSH-JUMP`, `OP-VERIFY-ACCESS`.
- **Files involved:** `outputs.tf` (four `ssh_*` outputs).
- **Commands:**
  `ssh -J ubuntu@<fip> ubuntu@192.168.100.55` (LMS),
  `… .91` (Odoo), `… .87` (Full-Stack-JS), `… .149` (Java-JS).
- **Validation procedure:** two-hop login succeeds; on target, `hostname`/`ip a`
  confirm identity.
- **Risks:** outputs hardcode IPs (`ISSUE-HARDCODED-IPS`) — if a VM is rebuilt with a
  new address, outputs lie until edited.
- **Future improvements:** `SSH-CONFIG` per-host aliases; DNS names via `FW-DOMAIN-DNS`.

### `SSH-CONFIG` — Persistent `~/.ssh/config` aliases

- **Type:** SSH Workflow · **Layer:** Operational
- **Description:** Client-side convenience encoding `SSH-PROXYJUMP`:

  ```sshconfig
  Host bastion
      HostName <floating-ip>
      User ubuntu

  Host lms odoo fullstack javajs
      User ubuntu
      ProxyJump bastion

  Host lms
      HostName 192.168.100.55
  Host odoo
      HostName 192.168.100.91
  Host fullstack
      HostName 192.168.100.87
  Host javajs
      HostName 192.168.100.149
  ```

- **Purpose:** `ssh lms` instead of the full `-J` incantation; stable aliases survive
  FIP changes (edit one line).
- **Dependencies:** `SSH-PROXYJUMP`.
- **Related Components:** `TFOUT-SSH-*` (source of the addresses), `FW-DOMAIN-DNS`
  (aliases eventually replaced by real names).
- **Files involved:** user-local `~/.ssh/config` (not in repo — per-operator).
- **Commands:** `ssh lms`, `scp file bastion:~/`, etc.
- **Validation procedure:** `ssh lms hostname` prints the target hostname.
- **Risks:** local config drifts from `ISSUE-HARDCODED-IPS` addresses — treat outputs
  as the generator.
- **Future improvements:** generate this file from `terraform output -json`
  (`FW-INVENTORY-AUTOMATION` sibling).

### `SSH-SCP-VIA-JUMP` — File transfer through the bastion

- **Type:** SSH Workflow · **Layer:** Operational
- **Description:** `scp -o ProxyJump=ubuntu@<fip> file ubuntu@192.168.100.87:~/` or
  `rsync -e 'ssh -J ubuntu@<fip>' …`. With `SSH-CONFIG` in place: `scp file lms:~/`.
- **Purpose:** Move artifacts (backups, logs, packages) to/from internal VMs without
  staging publicly.
- **Dependencies:** `SSH-PROXYJUMP`.
- **Related Components:** `DEC-006` (no agent forwarding ⇒ ProxyJump syntax mandatory).
- **Files involved:** none (ad-hoc commands).
- **Commands:** see description.
- **Validation procedure:** transferred file checksum matches.
- **Risks:** large transfers traverse the small bastion flavor — acceptable for ops,
  not for bulk data pipelines.
- **Future improvements:** none; object storage would supersede bulk use cases.

---

## Graph Relationships (local view)

```
ACTOR-ADMINS     CONNECTS_TO     VM-BASTION            (SSH-DIRECT-BASTION)
ACTOR-ADMINS     CONNECTS_TO     VM-LMS-OPENEDX · VM-ODOO-SERVER · VM-FULL-STACK-JS · VM-JAVA-JS
SSH-DIRECT-BASTION IS_ACCESSED_VIA INFRA-FIP
SSH-PROXYJUMP    USES            VM-BASTION
SSH-PROXYJUMP    CONNECTS_TO     VM-LMS-OPENEDX · VM-ODOO-SERVER · VM-FULL-STACK-JS · VM-JAVA-JS
SSH-CONFIG       IMPLEMENTS      SSH-PROXYJUMP
SSH-SCP-VIA-JUMP DEPENDS_ON      SSH-PROXYJUMP
DEC-006          RELATED_TO      SSH-PROXYJUMP          (AllowAgentForwarding no ⇒ -J)
TFOUT-SSH-BASTION      GENERATES command for SSH-DIRECT-BASTION
TFOUT-SSH-LMS-OPENEDX  GENERATES command for SSH-PROXYJUMP → VM-LMS-OPENEDX   (idem Odoo/FullStack/JavaJS)
VAL-SSH-BASTION  VALIDATES       SSH-DIRECT-BASTION
VAL-SSH-JUMP     VALIDATES       SSH-PROXYJUMP
```

---

## Decisions (canonical text in [decisions.md](decisions.md))

- `DEC-006` — ProxyJump instead of SSH agent forwarding (bastion holds no user keys).
- `DEC-007` — no direct-to-VM public access will be granted "temporarily" — ask for a
  ProxyJump alias instead.
- `DEC-010` — the bastion hop authenticates with the shared keypair until
  per-admin keys in `admin_ssh_keys` take over.

---

## Terraform Knowledge

- All four jump commands are **outputs** (`outputs.tf`), not data: they embed
  `TFVAR-BASTION-FLOATING-IP` and literal private IPs (`ISSUE-HARDCODED-IPS`).
- Regenerate commands after any change: `terraform output ssh_bastion` etc.,
  or all at once: `terraform output`.
- No Terraform resource models the *target-side* authorized keys of internal VMs
  (they predate automation) — key distribution there stays manual for now.

---

## Infrastructure Workflow

1. Deploy → `terraform output ssh_bastion` → verify `SSH-DIRECT-BASTION` (`VAL-SSH-BASTION`).
2. Verify each jump target (`VAL-SSH-JUMP` × pilot VMs).
3. Distribute `SSH-CONFIG` snippet to admins (optionally generated from outputs).
4. Ongoing: key/CIDR churn via `OP-ADD-SSH-KEY` / `OP-CHANGE-ADMIN-CIDR`.

---

## Validation

- `VAL-SSH-BASTION`: direct login; check `sshd -T | grep -E 'permitrootlogin|passwordauthentication'` → `no`.
- `VAL-SSH-JUMP`: for each VM: `ssh -J ubuntu@<fip> ubuntu@<ip> 'hostname && ip -4 addr show | grep 192.168'`.
- Negative control: from laptop without `-J`, `ssh ubuntu@192.168.100.87` must time out
  (proves `SG-PRIVATE-VMS` works).

---

## Operational Procedures

- **New admin joins:** `OP-ADD-SSH-KEY` (mind `ISSUE-USERDATA-DRIFT` — Ansible path)
  + `OP-CHANGE-ADMIN-CIDR` if their IP is new.
- **New VM onboarded:** after `OP-ADD-VM`/`OP-ATTACH-TO-BASTION`, add a
  `TFOUT-SSH-*` output and an `SSH-CONFIG` alias, then `OP-VERIFY-ACCESS`.
- **Lost access triage:** (1) is your IP still in `allowed_admin_cidrs`?
  (2) is the FIP still mapped? (3) does the bastion port still carry `SG-BASTION`?
  (4) does the VM port still carry `SG-PRIVATE-VMS`? Walk the chain in order.
- Full runbook: [operations.md](operations.md).

---

## Future Roadmap

- `FW-DOMAIN-DNS` — replace literal IPs in `SSH-CONFIG` with names.
- `FW-VAULT` — short-lived SSH certificates replace static keys (kills
  `ISSUE-SHARED-KEYPAIR` and `OP-ADD-SSH-KEY` toil).
- `FW-CICD` — pipeline SSH (Ansible runs) reuses these workflows with a CI identity.
- `FW-INVENTORY-AUTOMATION` — generate `SSH-CONFIG` + Ansible inventory from outputs.

---

## AI Retrieval Optimization

- **Keywords:** ssh -J, ProxyJump, jump host access, ssh config, scp through bastion, rsync jump, AllowAgentForwarding no, ssh ubuntu@, authorized_keys, key distribution, lockout triage
- **Tags:** #ssh #access #proxyjump #workflows #operators
- **Related Nodes:** `VM-BASTION`, `SG-BASTION`, `SG-PRIVATE-VMS`, `INFRA-FIP`, `TFOUT-SSH-*`, `INFRA-KEYPAIR`
- **Parent Nodes:** `PRIN-SINGLE-ENTRY`, `DEC-006`, `DEC-007`
- **Child Nodes:** `SSH-DIRECT-BASTION`, `SSH-PROXYJUMP`, `SSH-CONFIG`, `SSH-SCP-VIA-JUMP`, `ACTOR-ADMINS`
- **Cross References:** [bastion-host.md](bastion-host.md), [security-model.md](security-model.md), [operations.md](operations.md), [terraform-platform.md](terraform-platform.md)
- **Aliases:** accès SSH (fr), jump host workflow, bastion access, operator access
- **Infrastructure Layer:** none (workflow layer only)
- **Networking Layer:** FIP traversal
- **Security Layer:** key material map, `DEC-006`
- **Terraform Layer:** `TFOUT-SSH-*` outputs
- **Operational Layer:** all nodes in this document
