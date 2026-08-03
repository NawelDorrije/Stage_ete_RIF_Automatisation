# Feature: Terraform Platform (Module, Provider, Backend, Interface)

> Home document for: `TFMOD-ROOT`, `INFRA-TFCLOUD`, `DEPLOY-INIT`, `DEPLOY-PLAN`,
> `DEPLOY-APPLY`, all `TFVAR-*`, all `TFOUT-*`, all `TFDATA-*`,
> `ISSUE-HARDCODED-IPS`, `ISSUE-ORPHAN-FIP-SUBNET-VAR`,
> `ISSUE-TFVARS-EXAMPLE-INCOMPLETE`, `ISSUE-LOCKFILE-GITIGNORE`

---

## Overview

- **Purpose:** Define the automation engine itself: one root module that configures
  the entire bastion topology on OpenStack, with state in Terraform Cloud.
- **Context:** Terraform ≥ 1.7.0 (local toolchain v1.15.8), provider
  `terraform-provider-openstack/openstack ~> 1.53.0` (locked: 1.53.0).
- **Problem solved:** Reproducible, reviewable, remotely-stated infrastructure;
  a single `terraform apply` reconstructs the whole access layer.
- **Why it exists:** `PRIN-IAC` — every change flows through code review + plan/apply.

---

## Architecture

### Module file map (`TFMOD-ROOT` decomposition)

| File | Responsibility | Key nodes |
|---|---|---|
| `providers.tf` | `cloud {}` backend, provider auth + `endpoint_overrides`, 2 domain variables | `INFRA-TFCLOUD`, `INFRA-OPENSTACK-ENDPOINTS` |
| `variables.tf` | module input interface (15 variables) | `TFVAR-*` |
| `data.tf` | 5 read-only lookups of pre-existing cloud objects | `TFDATA-*` |
| `bastion.tf` | port, instance (+cloud-init), FIP association | `VM-BASTION`, `INFRA-BASTION-PORT`, `INFRA-FIP-ASSOC`, `INFRA-CLOUDINIT` |
| `security-groups.tf` | 2 SGs + 4 rules | `SG-*` |
| `existing-vms.tf` | SG association on legacy VM ports | `SG-ASSOC-PILOT-VMS` |
| `outputs.tf` | 7 outputs (2 IPs, 5 SSH commands) | `TFOUT-*` |
| `terraform.tfvars.example` | operator-facing configuration template | see `ISSUE-TFVARS-EXAMPLE-INCOMPLETE` |
| `.terraform.lock.hcl` | provider checksum lock | see `ISSUE-LOCKFILE-GITIGNORE` |
| `ansible/` | post-boot hardening mirror | `INFRA-ANSIBLE` |

### Execution order (implicit dependency DAG)

```
providers/auth ─▶ TFDATA-* (5 lookups, parallel)
SG-BASTION ─▶ SG-RULE-BASTION-* ─▶ INFRA-BASTION-PORT ─▶ VM-BASTION ─▶ INFRA-FIP-ASSOC
SG-BASTION ─▶ SG-RULE-VM-*-FROM-BASTION (remote_group_id)
SG-PRIVATE-VMS ─▶ SG-RULE-VM-* ; SG-PRIVATE-VMS ─▶ SG-ASSOC-PILOT-VMS (per map entry)
outputs resolved last (TFOUT-BASTION-PRIVATE-IP depends on the port)
```

### Security boundaries

- State (with sensitive values like `os_password`, `admin_ssh_keys`) lives remotely in
  `INFRA-TFCLOUD` — never commit `terraform.tfvars` (gitignored).
- Secrets enter via `TF_VAR_*` env vars or local `terraform.tfvars`.

---

## Graph Nodes

### `TFMOD-ROOT` — Root module `terraform-bastion`

- **Type:** Terraform Module · **Layer:** Terraform
- **Description:** The single module of this repository; `required_version >= 1.7.0`.
- **Purpose:** Configures every managed node: `VM-BASTION`, `INFRA-BASTION-PORT`,
  `INFRA-FIP-ASSOC`, `SG-BASTION`, `SG-PRIVATE-VMS`, `SG-ASSOC-PILOT-VMS`; generates
  all `TFOUT-*`.
- **Dependencies:** `INFRA-OPENSTACK` (provider), `INFRA-TFCLOUD` (backend).
- **Related Components:** `DEC-009`, all `TFVAR-*` (its interface), `VAL-FMT`,
  `VAL-VALIDATE`, `VAL-PLAN`, `VAL-APPLY`.
- **Files involved:** every `*.tf` in the module root.
- **Commands:** `terraform init|fmt|validate|plan|apply|output|state list`.
- **Validation procedure:** `VAL-VALIDATE` + clean `VAL-PLAN`.
- **Risks:** single module = blast radius of one apply covers the whole access layer;
  mitigated by `prevent_destroy` (`DEC-002`) and small surface.
- **Future improvements:** `FW-CICD` (PR-driven plans); module split (network/compute)
  only if the graph grows beyond the access layer.

### `INFRA-TFCLOUD` — Terraform Cloud Backend

- **Type:** Infrastructure Component · **Layer:** Terraform
- **Description:** `cloud { organization = "rif-stagiaires"; workspaces { name =
  "Nawel-Bastion-Test" } }` — remote state + (optionally) remote runs.
- **Purpose:** Shared, locked, versioned state; no local `*.tfstate` exists in the repo.
- **Dependencies:** Terraform Cloud account + `terraform login` token for CLI runs.
- **Related Components:** `DEC-009`, `DEPLOY-INIT` (authenticates to it), `FW-CICD`.
- **Files involved:** `providers.tf` (lines 1–8).
- **Commands:** `terraform login`, `terraform workspace show`.
- **Validation procedure:** `terraform init` succeeds; state visible in the
  `Nawel-Bastion-Test` workspace UI.
- **Risks:** workspace name is hardcoded — a second environment needs a new workspace
  + code edit; token expiry breaks CI.
- **Future improvements:** `FW-CICD` with workspace-per-environment naming.

### `DEPLOY-INIT` — `terraform init`

- **Type:** Deployment Step · **Layer:** Terraform
- **Description:** Installs provider 1.53.0 (per lock file), wires the cloud backend.
- **Dependencies:** `INFRA-TFCLOUD` (auth), network reachability of registry + TFC.
- **Commands:** `terraform init` (re-run after provider/backend changes: `-upgrade`).
- **Validation:** exit 0; `.terraform/` created; `terraform providers` lists openstack 1.53.0.
- **Risks:** `ISSUE-LOCALHOST-ENDPOINTS` does **not** affect init (registry/TFC are
  remote) but affects plan/apply.

### `DEPLOY-PLAN` — `terraform plan`

- **Type:** Deployment Step · **Layer:** Terraform
- **Description:** Resolves data sources, diffs desired vs. state. The review gate.
- **Dependencies:** `DEPLOY-INIT`, reachability of all `INFRA-OPENSTACK-ENDPOINTS`.
- **Commands:** `terraform plan` (expect: only intended changes; for VM attach: exactly
  one `+` association).
- **Validation:** human review against the change request (`VAL-PLAN`).
- **Risks:** data-source resolution errors = name mismatch in tfvars, not a cloud fault.

### `DEPLOY-APPLY` — `terraform apply`

- **Type:** Deployment Step · **Layer:** Terraform
- **Description:** Executes the plan against OpenStack; writes remote state.
- **Dependencies:** `DEPLOY-PLAN` approval.
- **Commands:** `terraform apply` (then `terraform output` for SSH commands).
- **Validation:** `VAL-APPLY` + functional ladder (`VAL-SSH-BASTION` → `VAL-SSH-JUMP`).
- **Risks:** `prevent_destroy` blocks destroying bastion/port — apply will error, by
  design (`DEC-002`); see `OP-ROLLBACK` for the sanctioned teardown path.

### Variables (`TFVAR-*` cards — tabular form)

| ID / variable | Type / default | Configures | Description & purpose | Risks / notes |
|---|---|---|---|---|
| `TFVAR-OS-USERNAME` `os_username` | string, **required** | provider auth | OpenStack user | not in tfvars example (`ISSUE-TFVARS-EXAMPLE-INCOMPLETE`) |
| `TFVAR-OS-PASSWORD` `os_password` | string, required, **sensitive** | provider auth | OpenStack password | keep in env/`TF_VAR_os_password`; lands in remote state |
| `TFVAR-OS-PROJECT-NAME` `os_project_name` | string, required | provider auth | tenant/project | same delivery caveats as password |
| `TFVAR-OS-USER-DOMAIN-NAME` `os_user_domain_name` | string, `"Default"` | provider auth | user domain (declared in `providers.tf`) | — |
| `TFVAR-OS-PROJECT-DOMAIN-NAME` `os_project_domain_name` | string, `"Default"` | provider auth | project domain (declared in `providers.tf`) | — |
| `TFVAR-PRIVATE-NETWORK-NAME` `private_network_name` | string, `"reseau-stagiaires"` | `TFDATA-PRIVATE-NETWORK` | names the legacy network | rename breaks data lookup at plan time |
| `TFVAR-PRIVATE-SUBNET-NAME` `private_subnet_name` | string, `"subnet-stagiaires"` | `TFDATA-PRIVATE-SUBNET` | names the subnet | idem |
| `TFVAR-EXTERNAL-NETWORK-NAME` `external_network_name` | string, `"public"` | `TFDATA-EXTERNAL-NETWORK` | FIP pool network | data source currently unused by resources |
| `TFVAR-FLOATING-IP-SUBNET-ID` `floating_ip_subnet_id` | string, **required** | *(nothing active)* | public subnet for a managed FIP | **`ISSUE-ORPHAN-FIP-SUBNET-VAR`** |
| `TFVAR-BASTION-NAME` `bastion_name` | string, `"bastion-nawel-test"` | `VM-BASTION`, port name | instance/port naming | rename = instance recreation (blocked by `DEC-002`) |
| `TFVAR-BASTION-IMAGE-NAME` `bastion_image_name` | string, `"Ubuntu-22.04"` | `TFDATA-UBUNTU-IMAGE` | base image selector | `most_recent` drift (see `INFRA-IMAGE`) |
| `TFVAR-BASTION-FLAVOR-NAME` `bastion_flavor_name` | string, `"m1.small-custom"` | `TFDATA-BASTION-FLAVOR` | sizing | change = recreation (blocked) |
| `TFVAR-EXISTING-KEYPAIR-NAME` `existing_keypair_name` | string, `"Full_Stack_JS_key"` | `VM-BASTION` key_pair | boot keypair | `ISSUE-SHARED-KEYPAIR`; change = recreation |
| `TFVAR-ADMIN-SSH-KEYS` `admin_ssh_keys` | list(string), `[]`, **sensitive** | `INFRA-CLOUDINIT` | extra authorized keys | **only first-boot** — `ISSUE-USERDATA-DRIFT` |
| `TFVAR-ALLOWED-ADMIN-CIDR` `allowed_admin_cidrs` | list(string), **required** | `SG-RULE-BASTION-SSH` | admin source allowlist | always `/32`; see `OP-CHANGE-ADMIN-CIDR` |
| `TFVAR-EXISTING-VM-PORTS` `existing_vm_ports` | map(string), **required** | `SG-ASSOC-PILOT-VMS` | logical name → Port UUID | `ISSUE-MANUAL-PORT-ID`; key rename = recreate association |
| `TFVAR-BASTION-FLOATING-IP` `bastion_floating_ip` | string, **required** | `INFRA-FIP-ASSOC`, all `TFOUT-*` | the pre-existing FIP value | absent from tfvars example (`ISSUE-TFVARS-EXAMPLE-INCOMPLETE`) |

### Outputs (`TFOUT-*` cards — tabular form)

| ID / output | Value built from | Purpose | Notes |
|---|---|---|---|
| `TFOUT-BASTION-PRIVATE-IP` `bastion_private_ip` | `INFRA-BASTION-PORT.all_fixed_ips[0]` | private address of the bastion | depends on port ordering |
| `TFOUT-BASTION-FLOATING-IP` `bastion_floating_ip` | `TFVAR-BASTION-FLOATING-IP` | echo of the public address | — |
| `TFOUT-SSH-BASTION` `ssh_bastion` | FIP | `ssh ubuntu@<fip>` | `SSH-DIRECT-BASTION` |
| `TFOUT-SSH-LMS-OPENEDX` `ssh_lms_openedx` | FIP + `192.168.100.55` | jump command to LMS | `ISSUE-HARDCODED-IPS` |
| `TFOUT-SSH-ODOO-SERVER` `ssh_odoo_server` | FIP + `192.168.100.91` | jump command to Odoo | `ISSUE-HARDCODED-IPS` |
| `TFOUT-SSH-FULL-STACK-JS` `ssh_full_stack_js` | FIP + `192.168.100.87` | jump command to Full-Stack-JS | `ISSUE-HARDCODED-IPS` |
| `TFOUT-SSH-JAVA-JS` `ssh_java_js` | FIP + `192.168.100.149` | jump command to Java-JS | `ISSUE-HARDCODED-IPS` |

### Data sources (`TFDATA-*` cards — tabular form)

| ID / data source | Looks up | Consumed by | Failure mode |
|---|---|---|---|
| `TFDATA-PRIVATE-NETWORK` | `NET-PRIVATE` by name | `INFRA-BASTION-PORT` | plan-time "network not found" |
| `TFDATA-PRIVATE-SUBNET` | `NET-PRIVATE-SUBNET` by name | port `fixed_ip` | idem |
| `TFDATA-EXTERNAL-NETWORK` | `NET-EXTERNAL` by name | *(reserved for managed FIP, `DEC-001`)* | idem |
| `TFDATA-UBUNTU-IMAGE` | newest `Ubuntu-22.04` | `VM-BASTION` image_id | ambiguous if multiple matches |
| `TFDATA-BASTION-FLAVOR` | `m1.small-custom` | `VM-BASTION` flavor_id | "flavor not found" |

### Issue nodes

#### `ISSUE-HARDCODED-IPS` — Outputs freeze private IPs in code

- **Type:** Known Issue · **Layer:** Terraform + Operational
- **Description:** `192.168.100.55/.87/.91/.149` are string literals in `outputs.tf`.
  A VM rebuilt with a new IP silently invalidates the documented commands.
- **Mitigation:** treat outputs as convenience only; verify with
  `openstack server list` when in doubt.
- **Future fix:** derive IPs from data sources (`FW-PORT-AUTODISCOVERY`) or remove
  per-VM outputs once `SSH-CONFIG`/DNS exists.
- **Files:** `outputs.tf` (lines 16–34).

#### `ISSUE-ORPHAN-FIP-SUBNET-VAR` — Required variable used only by commented code

- **Type:** Known Issue · **Layer:** Terraform
- **Description:** `floating_ip_subnet_id` is required (no default) but its only
  reference is inside the commented-out `openstack_networking_floatingip_v2` resource
  (`DEC-001`). Every run demands a value that influences nothing.
- **Mitigation:** set a placeholder; keep for the day managed FIP returns.
- **Future fix:** either delete the variable or re-enable the managed FIP with import.
- **Files:** `variables.tf` (lines 32–35), `bastion.tf` (lines 74–84).

#### `ISSUE-TFVARS-EXAMPLE-INCOMPLETE` — Example tfvars omits 4 required inputs

- **Type:** Known Issue · **Layer:** Terraform + Operational
- **Description:** `terraform.tfvars.example` documents 11 keys but not `os_username`,
  `os_password`, `os_project_name`, `bastion_floating_ip` — all required. New operators
  hit prompts/errors on first `plan` unless they use `TF_VAR_*` env vars.
- **Mitigation:** document the env-var pattern (below) in onboarding.
- **Future fix:** add commented placeholders for the missing four.
- **Files:** `terraform.tfvars.example`.

#### `ISSUE-LOCKFILE-GITIGNORE` — Lock-file ignore pattern is ineffective (leading space)

- **Type:** Known Issue · **Layer:** Terraform (repo hygiene)
- **Description:** `.gitignore` line 21 is `" .terraform.lock.hcl"` with a **leading
  space**, so git does not treat it as a match; the lock file is therefore tracked.
  The surrounding comment frames this as "keep versioned for shared projects", so the
  *outcome* is currently desirable — but the mechanism is accidental and brittle.
- **Mitigation:** none needed while tracking is intended.
- **Future fix:** either delete the broken pattern line or fix the comment to state
  "intentionally tracked".
- **Files:** `.gitignore` (line 21), `.terraform.lock.hcl` (tracked, provider 1.53.0).

---

## Graph Relationships (local view)

```
TFMOD-ROOT   CONFIGURES  VM-BASTION · INFRA-BASTION-PORT · INFRA-FIP-ASSOC · SG-BASTION · SG-PRIVATE-VMS · SG-ASSOC-PILOT-VMS
TFMOD-ROOT   DEPENDS_ON  INFRA-OPENSTACK
TFMOD-ROOT   USES        INFRA-TFCLOUD
TFMOD-ROOT   GENERATES   TFOUT-* (all seven)
TFDATA-*     DEPENDS_ON  NET-PRIVATE · NET-PRIVATE-SUBNET · NET-EXTERNAL · INFRA-IMAGE · INFRA-FLAVOR
TFVAR-*      CONFIGURES  (per table above)
DEPLOY-PLAN  DEPENDS_ON  DEPLOY-INIT
DEPLOY-APPLY DEPENDS_ON  DEPLOY-PLAN
DEPLOY-INIT  DEPENDS_ON  INFRA-TFCLOUD
DEC-009      RELATED_TO  INFRA-TFCLOUD
ISSUE-ORPHAN-FIP-SUBNET-VAR RELATED_TO TFVAR-FLOATING-IP-SUBNET-ID · DEC-001
ISSUE-HARDCODED-IPS RELATED_TO TFOUT-SSH-* (all four)
VAL-VALIDATE VALIDATES   TFMOD-ROOT
VAL-PLAN     VALIDATES   TFMOD-ROOT
```

---

## Decisions (canonical text in [decisions.md](decisions.md))

- `DEC-009` — Terraform Cloud remote backend (shared state, locking).
- `DEC-001` — managed-FIP resource kept commented (explains the orphan variable).
- `DEC-002` / `DEC-003` — lifecycle rules that shape every plan.

---

## Terraform Knowledge (collected)

- **Provider pinning:** constraint `~> 1.53.0`, locked to `1.53.0` in
  `.terraform.lock.hcl` (tracked — see `ISSUE-LOCKFILE-GITIGNORE`).
- **Secret delivery:** `TF_VAR_os_username`, `TF_VAR_os_password`,
  `TF_VAR_os_project_name`, `TF_VAR_bastion_floating_ip` as environment variables,
  or a local gitignored `terraform.tfvars`.
- **Lifecycle inventory:** `prevent_destroy` on port + instance; `ignore_changes` on
  `user_data`; nothing else managed is lifecycle-protected.
- **State:** remote only, workspace `Nawel-Bastion-Test`; no local `*.tfstate` in repo.

---

## Infrastructure Workflow

```bash
terraform login                 # once, for INFRA-TFCLOUD
terraform init                  # DEPLOY-INIT
terraform fmt -check            # VAL-FMT
terraform validate              # VAL-VALIDATE
terraform plan                  # DEPLOY-PLAN  (review gate: VAL-PLAN)
terraform apply                 # DEPLOY-APPLY (VAL-APPLY)
terraform output                # retrieve TFOUT-* SSH commands
```

Rollback → `OP-ROLLBACK` / `DEPLOY-ROLLBACK` (→ See: [operations.md](operations.md)).

---

## Validation

`VAL-FMT` → `VAL-VALIDATE` → `VAL-PLAN` → `VAL-APPLY` (details in
[operations.md](operations.md) validation ladder).

---

## Operational Procedures

- **First-time setup:** install Terraform ≥ 1.7, `terraform login`, provide the four
  secrets (`ISSUE-TFVARS-EXAMPLE-INCOMPLETE`), `DEPLOY-INIT`.
- **Every change:** branch → edit → `VAL-FMT`/`VAL-VALIDATE` → `DEPLOY-PLAN` review →
  `DEPLOY-APPLY` → functional validation ladder.
- **Provider upgrade:** edit constraint, `terraform init -upgrade`, commit the
  updated `.terraform.lock.hcl`.

---

## Future Roadmap

- `FW-CICD` — PR plans + gated applies (blocked by `ISSUE-LOCALHOST-ENDPOINTS` until
  runners can reach the endpoints).
- `FW-VAULT` — replace `TF_VAR_*` secret delivery.
- `FW-PORT-AUTODISCOVERY` — kills both `ISSUE-MANUAL-PORT-ID` and `ISSUE-HARDCODED-IPS`.
- `FW-INVENTORY-AUTOMATION` — `terraform output -json` → Ansible inventory + SSH config.

---

## AI Retrieval Optimization

- **Keywords:** terraform module, openstack provider 1.53.0, terraform cloud, rif-stagiaires, Nawel-Bastion-Test workspace, required_version 1.7, variables, tfvars, outputs, data sources, terraform plan apply init, state, lock file, TF_VAR, endpoint_overrides
- **Tags:** #terraform #iac #module #provider #backend #variables #outputs
- **Related Nodes:** `INFRA-OPENSTACK`, `VM-BASTION`, `SG-*`, `DEPLOY-*`, `DEC-009`
- **Parent Nodes:** `PRIN-IAC`
- **Child Nodes:** `TFMOD-ROOT`, `INFRA-TFCLOUD`, all `TFVAR-*`/`TFOUT-*`/`TFDATA-*`, `DEPLOY-INIT/PLAN/APPLY`
- **Cross References:** [operations.md](operations.md), [decisions.md](decisions.md), [networking.md](networking.md), [bastion-host.md](bastion-host.md)
- **Aliases:** IaC layer, automation engine, module racine (fr), Terraform workspace
- **Infrastructure Layer:** none (meta-layer)
- **Networking Layer:** `INFRA-OPENSTACK-ENDPOINTS` (provider config)
- **Security Layer:** secret delivery, sensitive variables
- **Terraform Layer:** everything in this document
- **Operational Layer:** `ISSUE-TFVARS-EXAMPLE-INCOMPLETE`, `ISSUE-LOCKFILE-GITIGNORE`, setup procedure
