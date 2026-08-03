# Feature: Future Roadmap (Future Work as Graph Nodes)

> Home document for: `RP-NGINX`, `FW-REVERSE-PROXY`, `FW-HTTPS`, `FW-DOMAIN-DNS`,
> `FW-DNS-FIX`, `FW-PROMETHEUS`, `FW-GRAFANA`, `FW-VAULT`, `FW-CICD`,
> `FW-ENFORCE-SG`, `FW-MERN-ONBOARDING`, `FW-PORT-AUTODISCOVERY`,
> `FW-INVENTORY-AUTOMATION`, `VM-MERN-FRONTEND`, `VM-MERN-BACKEND`, `VM-MERN-MONGODB`

Future work is modeled as **first-class graph nodes** with dependency edges into the
existing graph, so impact analysis works on things that don't exist yet.

---

## Overview

- **Purpose:** Give every planned evolution a node with dependencies, so answering
  "what must exist before HTTPS?" is a graph traversal:
  `FW-HTTPS ← RP-NGINX ← VM-BASTION` and `FW-HTTPS ← FW-DOMAIN-DNS ← FW-DNS-FIX`.
- **Context:** The bastion phase (this repo's current state) is the foundation layer;
  everything below builds on it.

---

## Dependency Chains (roadmap as graph)

```
INFRA-OPENSTACK (today)
  └─ VM-BASTION (today)
       ├─ RP-NGINX (done 2026-08-03) ─▶ FW-HTTPS ◀─ FW-DOMAIN-DNS ◀─ FW-DNS-FIX ◀─ ISSUE-DNS
       ├─ FW-PROMETHEUS ─▶ FW-GRAFANA
       ├─ FW-VAULT ─▶ (kills ISSUE-SHARED-KEYPAIR, TF_VAR_* secrets)
       └─ FW-CICD ◀─ ISSUE-LOCALHOST-ENDPOINTS (must be solved first)
SG-ASSOC-PILOT-VMS (today)
  ├─ FW-ENFORCE-SG (SUPERSEDES DEC-004)
  ├─ FW-MERN-ONBOARDING ─▶ VM-MERN-FRONTEND / VM-MERN-BACKEND / VM-MERN-MONGODB
  └─ FW-PORT-AUTODISCOVERY (SUPERSEDES ISSUE-MANUAL-PORT-ID)
INFRA-ANSIBLE (today)
  └─ FW-INVENTORY-AUTOMATION ◀─ TFOUT-*
```

---

## Graph Nodes

### `RP-NGINX` — Reverse proxy on the bastion (NGINX or Traefik)

- **Type:** Reverse Proxy · **Layer:** Infrastructure + Security · **Status:** **implemented (HTTP, 2026-08-03)** — graduated to [reverse-proxy.md](reverse-proxy.md); HTTPS pass 2 still tracked by `FW-HTTPS`
- **Description:** A reverse proxy co-located on `VM-BASTION` (or a small dedicated VM
  if load demands), terminating HTTP(S) and forwarding to internal VMs
  (LMS-OpenedX :80, Odoo :8069, app ports).
- **Purpose:** Give **users** (not admins) access to hosted applications without
  per-VM Floating IPs — extends `DEC-007`/`PRIN-SINGLE-ENTRY` from SSH to HTTP.
- **Dependencies:** `VM-BASTION` (E124), `SG-BASTION` (needs new 80/443 ingress rules),
  `INFRA-FIP` (same public IP multiplexes SSH + HTTP(S)).
- **Related Components:** `FW-HTTPS` (TLS terminates here), `FW-DOMAIN-DNS` (vhosts).
- **Files involved:** none yet — would add `reverse-proxy.tf` (or Ansible role) +
  rules in `security-groups.tf`.
- **Commands:** (future) `curl -H 'Host: lms.example' http://<fip>`.
- **Validation procedure:** vhost routing table returns correct backend per hostname;
  direct backend ports unreachable from outside.
- **Risks:** bastion SPOF now also gates user traffic; sizing of `INFRA-FLAVOR`
  must be revisited.
- **Future improvements:** HA pair behind the FIP; WAF rules; rate limiting.
- **Implements:** `FW-REVERSE-PROXY` (E123).
- **→ Canonical card:** [reverse-proxy.md](reverse-proxy.md) (`RP-NGINX`, first vhost
  `RP-VHOST-JAVAJS`: `rif-javajs.duckdns.org` → `192.168.100.149:80`).

### `FW-REVERSE-PROXY` — Central HTTP(S) entry for hosted apps

- **Type:** Future Work · **Layer:** Infrastructure · **Status:** planned
- **Purpose:** the capability node implemented by `RP-NGINX`.
- **Dependencies:** `VM-BASTION` (via `RP-NGINX`).
- **Validation:** users reach apps by name over HTTPS; no app port is public.
- **Risks:** see `RP-NGINX`. **Future improvements:** see `RP-NGINX`.

### `FW-HTTPS` — TLS certificates (Let's Encrypt)

- **Type:** Future Work · **Layer:** Security · **Status:** **implemented (pass 2, 2026-08-03)** — `rif-javajs.duckdns.org` serves HTTPS via certbot `certonly --webroot`
- **Description:** Automated certificate issuance/renewal (certbot) on `RP-NGINX`:
  `certonly --webroot -w /var/www/certbot`; the vhost template owns the nginx config
  (443 + redirect), so certbot never edits nginx (avoids template/certbot conflicts).
- **Purpose:** Encrypt user traffic; prerequisite for any real user onboarding.
- **Dependencies:** `RP-NGINX` (E125 — **satisfied**), `FW-DOMAIN-DNS` (E126 — ACME
  HTTP-01 needs a public name pointing at `INFRA-FIP`; DuckDNS `rif-javajs` now
  resolves to the bastion, kept in sync by the role's cron).
- **Related Components:** `SG-BASTION` (443 ingress — **satisfied** via
  `SG-RULE-BASTION-HTTPS`).
- **Files involved:** `ansible/roles/reverse_proxy/tasks/certbot.yml`,
  `ansible/roles/reverse_proxy/templates/reverse-proxy.conf.j2` (TLS server block);
  toggles `reverse_proxy_enable_https` + `certbot_email` in
  `ansible/group_vars/bastion.yml`.
- **Commands:** `certbot certificates`, `openssl s_client -connect <fip>:443 -servername <name>`.
- **Validation procedure:** TLS handshake valid, expiry > 30 days, auto-renew timer active.
- **Risks:** renewal failures if port 80 path is broken; rate limits on a shared FIP;
  the bastion's resolver intermittently drops the first lookup of a new name — the
  dry-run task retries and DuckDNS/curl use `--retry`.
- **Future improvements:** wildcard via DNS-01 once `FW-DOMAIN-DNS` supports API.

### `FW-DOMAIN-DNS` — Domain names for services

- **Type:** Future Work · **Layer:** Networking · **Status:** planned
- **Description:** Public DNS records (e.g. `lms.<domain>`, `odoo.<domain>`,
  `bastion.<domain>`) pointing at `INFRA-FIP`; possibly internal DNS on `NET-PRIVATE`.
- **Purpose:** Replace IP literals (`ISSUE-HARDCODED-IPS`) with names for both users
  (via `RP-NGINX` vhosts) and operators (`SSH-CONFIG` HostNames).
- **Dependencies:** `FW-DNS-FIX` (E127).
- **Related Components:** `FW-HTTPS`, `SSH-CONFIG`.
- **Files involved:** future `dns.tf` (OpenStack Designate or external provider).
- **Commands:** `dig lms.<domain> +short` → FIP.
- **Validation procedure:** records resolve publicly; vhost names match certificates.
- **Risks:** DNS zone ownership/delegation outside current project scope.
- **Future improvements:** internal split-horizon zone for `192.168.100.0/24` names.

### `FW-DNS-FIX` — Complete the DNS work of branch `fix/dns-terraform`

- **Type:** Future Work (active) · **Layer:** Networking · **Status:** **in progress**
- **Description:** The current working branch `fix/dns-terraform` indicates DNS-related
  changes are underway; no DNS resources exist in the module yet. This node tracks
  finishing and merging that work.
- **Purpose:** Unblock `FW-DOMAIN-DNS`.
- **Dependencies:** `NET-PRIVATE` (E-edge via `ISSUE-DNS`).
- **Related Components:** `ISSUE-DNS` (E128).
- **Files involved:** branch `fix/dns-terraform` (diff vs. `main` to be merged).
- **Commands:** `git log main..fix/dns-terraform --oneline`.
- **Validation procedure:** DNS resources (once defined) plan/apply cleanly; resolution
  works from inside `NET-PRIVATE`.
- **Risks:** unknown until branch content is merged — document findings in `ISSUE-DNS`.
- **Future improvements:** feeds `FW-DOMAIN-DNS`.

### `FW-PROMETHEUS` — Metrics collection

- **Type:** Future Work · **Layer:** Operational · **Status:** planned
- **Description:** Prometheus server (on the bastion or a dedicated small VM) +
  `node_exporter` on every `VM-*`; scrape over `NET-PRIVATE`.
- **Purpose:** Visibility into the currently unmonitored fleet.
- **Dependencies:** all `VM-*` (targets); `SG-PRIVATE-VMS`-style SG rule for port 9100
  from the monitoring host.
- **Related Components:** `FW-GRAFANA` (E129), `INFRA-ANSIBLE` (exporter install path).
- **Files involved:** future `monitoring.tf` + Ansible role.
- **Commands:** `curl http://<vm>:9100/metrics`.
- **Validation procedure:** all targets `UP` in Prometheus; SG allows 9100 only from
  the monitoring host.
- **Risks:** metrics endpoints widening attack surface if SGs are sloppy.
- **Future improvements:** Alertmanager to mail/Mattermost; blackbox exporter probing
  `RP-NGINX` vhosts.

### `FW-GRAFANA` — Dashboards

- **Type:** Future Work · **Layer:** Operational · **Status:** planned
- **Description:** Grafana fronting `FW-PROMETHEUS`, exposed via `RP-NGINX` vhost
  (`grafana.<domain>`), never via its own FIP.
- **Purpose:** Human-friendly fleet health.
- **Dependencies:** `FW-PROMETHEUS` (E129); exposure path via `RP-NGINX` + `FW-HTTPS`.
- **Validation:** login over HTTPS; dashboards render all four VMs.
- **Risks:** default admin credentials — rotate at install (Ansible).
- **Future improvements:** SSO/OAuth once identity exists.

### `FW-VAULT` — Secrets management

- **Type:** Future Work · **Layer:** Security · **Status:** planned
- **Description:** HashiCorp Vault (or lightweight alternative) to inject
  `TF_VAR_os_password` at run time, store SSH material, and eventually issue
  short-lived SSH certificates.
- **Purpose:** Eliminate plaintext secrets in tfvars/env and shared static keys.
- **Dependencies:** `TFMOD-ROOT` (auth method), `INFRA-OPENSTACK` (secret engines).
- **Related Components:** `ISSUE-SHARED-KEYPAIR` (superseded), `OP-ADD-SSH-KEY`
  (superseded by SSH CA), `TFVAR-OS-PASSWORD`.
- **Files involved:** future `vault/` config + CI integration.
- **Commands:** `vault kv get openstack/creds`.
- **Validation procedure:** `terraform plan` runs with Vault-sourced credentials and
  no local secret files.
- **Risks:** Vault itself becomes critical infrastructure needing backup/unseal ops.
- **Future improvements:** Vault SSH CA replaces `authorized_keys` management.

### `FW-CICD` — CI/CD pipeline for Terraform/Ansible

- **Type:** Future Work · **Layer:** Operational · **Status:** planned
- **Description:** PR-triggered `fmt`/`validate`/`plan` (posted as comments), gated
  `apply` on merge; Ansible lint + converge in CI.
- **Purpose:** Enforce `PRIN-IAC` mechanically; run validation ladder steps 1–4
  automatically.
- **Dependencies:** `INFRA-TFCLOUD` (remote runs) **and a solution to
  `ISSUE-LOCALHOST-ENDPOINTS`** (runner must reach the endpoints — on-host runner or
  tunnel) — E133 makes this a hard blocker.
- **Related Components:** `DEC-012` (likely needs revisiting), `FW-VAULT` (CI secrets).
- **Files involved:** future `.github/workflows/` or `.gitlab-ci.yml`.
- **Commands:** n/a (pipeline definitions).
- **Validation procedure:** a test PR shows a correct plan comment; merge applies
  without local credentials.
- **Risks:** CI hold credentials = high-value target; requires `FW-VAULT` or TFC
  dynamic credentials.
- **Future improvements:** drift-detection scheduled plans.

### `FW-ENFORCE-SG` — Switch pilot association to exclusive SG control

- **Type:** Future Work · **Layer:** Security · **Status:** planned (post-pilot)
- **Description:** After phases 1–2 validate, flip `enforce = false` → `true` (or
  rebuild VM ports with only `SG-PRIVATE-VMS`), retiring legacy SGs.
- **Purpose:** Close the additive gap left by `DEC-004`; make the bastion the *only*
  SSH path (`PRIN-SINGLE-ENTRY` fully realized).
- **Dependencies:** `SG-ASSOC-PILOT-VMS`; completion of `DEC-005` phases.
- **Supersedes:** `DEC-004` (E121).
- **Files involved:** `existing-vms.tf` (one-line change, big effect).
- **Commands:** before flipping: `openstack port show <port> -c security_group_ids`
  (inventory legacy rules); after: negative control from laptop fails everywhere.
- **Validation procedure:** full ladder + negative controls on every VM; confirm no
  legacy path remains.
- **Risks:** unknown legacy consumers (other admins' direct paths) get cut — communicate
  before enforcing; keep rollback = flip back + apply.
- **Future improvements:** none (end-state of the security model).

### `FW-MERN-ONBOARDING` — Attach the MERN stack to the bastion model

- **Type:** Future Work · **Layer:** Infrastructure · **Status:** planned (phase 3)
- **Description:** Onboard `VM-MERN-FRONTEND`, `VM-MERN-BACKEND`, `VM-MERN-MONGODB`
  (placeholders already present in `terraform.tfvars.example`) via `OP-ADD-VM` +
  `OP-ATTACH-TO-BASTION`.
- **Purpose:** Extend the validated model to the remaining training stack.
- **Dependencies:** `SG-ASSOC-PILOT-VMS` (E130), `DEC-005` phase gating.
- **Related Components:** `RP-NGINX` (frontend exposure path), MongoDB SG rules
  (backend→mongo 27017 — a *new* rule family, not from bastion).
- **Files involved:** `terraform.tfvars` (uncomment placeholders), `outputs.tf`.
- **Commands:** per `OP-ADD-VM`.
- **Validation procedure:** `OP-VERIFY-ACCESS` × 3; app-tier connectivity tests
  (backend → mongodb).
- **Risks:** MERN needs inter-VM rules the current graph doesn't model yet (27017) —
  design new SGs, don't widen `SG-PRIVATE-VMS`.
- **Future improvements:** per-role SGs (`sg-mern-backend`, `sg-mern-db`).

#### MERN VM nodes (compact cards)

| Node | Type | Status | Purpose | Dependencies | Validation | Risks |
|---|---|---|---|---|---|---|
| `VM-MERN-FRONTEND` | VM | placeholder in tfvars | serve the MERN UI | `NET-PRIVATE`, `FW-MERN-ONBOARDING` | `OP-VERIFY-ACCESS`; vhost via `RP-NGINX` later | public exposure must wait for `RP-NGINX` |
| `VM-MERN-BACKEND` | VM | placeholder | API tier | `NET-PRIVATE`, `VM-MERN-MONGODB` | SSH via bastion + API health check | needs new SG rule to MongoDB |
| `VM-MERN-MONGODB` | VM | placeholder | database tier | `NET-PRIVATE` | SSH via bastion + `mongod` listening on private IP | must never get public exposure; 27017 only from backend SG |

### `FW-PORT-AUTODISCOVERY` — Replace manual Port IDs with data-source lookups

- **Type:** Future Work · **Layer:** Terraform · **Status:** planned
- **Description:** Replace pasted UUIDs in `existing_vm_ports` with a lookup such as
  `data "openstack_networking_port_ids_v2" "by_ip" { fixed_ip = "192.168.100.87" }`
  keyed off values Terraform can verify.
- **Purpose:** Remove `ISSUE-MANUAL-PORT-ID` toil and the wrong-port risk; enables
  deriving `TFOUT-SSH-*` IPs too (also fixes `ISSUE-HARDCODED-IPS`).
- **Dependencies:** provider support (openstack 1.53.0 has
  `openstack_networking_port_ids_v2`).
- **Supersedes:** `ISSUE-MANUAL-PORT-ID` (E122).
- **Files involved:** `data.tf`, `existing-vms.tf`, `variables.tf`, `outputs.tf`.
- **Commands:** `terraform plan` shows identical associations (no churn) after refactor.
- **Validation procedure:** refactor apply = empty plan; `VAL-SG-AUDIT` unchanged.
- **Risks:** fixed-IP-based lookup breaks if a VM is rebuilt with a new IP — but then
  the *failure is loud* instead of silently protecting the wrong port (strictly better).
- **Future improvements:** feed discovered IPs into `TFOUT-SSH-*`.

### `FW-INVENTORY-AUTOMATION` — Generate Ansible inventory (and SSH config) from outputs

- **Type:** Future Work · **Layer:** Operational · **Status:** planned
- **Description:** A small template/`local-exec` step rendering
  `ansible/inventory.ini` (and optionally `~/.ssh/config` snippets) from
  `terraform output -json`; replaces the empty `inventory.ini.example` and the manual
  step in `OP-RUN-ANSIBLE`.
- **Purpose:** Single source of truth for connection data; onboarding in one command.
- **Dependencies:** `INFRA-ANSIBLE` (E131), `TFOUT-*`.
- **Files involved:** future `templates/inventory.tftpl`, `outputs.tf`.
- **Commands:** `terraform output -json | ./scripts/gen-inventory.sh`.
- **Validation procedure:** generated inventory passes `ansible-inventory --list`;
  `OP-RUN-ANSIBLE` works with zero manual edits.
- **Risks:** generated file contains the FIP — keep gitignored (already covered).
- **Future improvements:** fold into `FW-CICD` as a post-apply artifact.

---

## Graph Relationships (roadmap edges, consolidated)

```
RP-NGINX  IMPLEMENTS  FW-REVERSE-PROXY
RP-NGINX  DEPENDS_ON  VM-BASTION
FW-HTTPS  DEPENDS_ON  RP-NGINX · FW-DOMAIN-DNS
FW-DOMAIN-DNS DEPENDS_ON FW-DNS-FIX
FW-DNS-FIX RELATED_TO ISSUE-DNS
FW-GRAFANA DEPENDS_ON FW-PROMETHEUS
FW-PROMETHEUS DEPENDS_ON VM-BASTION · VM-FULL-STACK-JS · VM-LMS-OPENEDX · VM-ODOO-SERVER · VM-JAVA-JS
FW-CICD   DEPENDS_ON  INFRA-TFCLOUD · (blocked by) ISSUE-LOCALHOST-ENDPOINTS
FW-VAULT  RELATED_TO  ISSUE-SHARED-KEYPAIR · TFVAR-OS-PASSWORD
FW-ENFORCE-SG SUPERSEDES DEC-004
FW-MERN-ONBOARDING DEPENDS_ON SG-ASSOC-PILOT-VMS · VM-MERN-FRONTEND · VM-MERN-BACKEND · VM-MERN-MONGODB
FW-PORT-AUTODISCOVERY SUPERSEDES ISSUE-MANUAL-PORT-ID
FW-INVENTORY-AUTOMATION DEPENDS_ON INFRA-ANSIBLE · TFOUT-*
```

---

## Decisions / Terraform Knowledge / Workflow / Validation / Operational Procedures

Not applicable to future nodes individually — each future node above carries its own
validation sketch. When a future node becomes current, it graduates into its own
feature document (or merges into the closest existing one) and this entry is replaced
by a `SUPERSEDES`/implementation edge.

---

## AI Retrieval Optimization

- **Keywords:** roadmap, future work, reverse proxy, nginx, traefik, https, letsencrypt, certbot, domain names, dns, designate, prometheus, grafana, monitoring, vault, secrets, cicd, pipeline, mern stack, enforce security groups, port autodiscovery, ansible inventory generation
- **Tags:** #roadmap #future #reverse-proxy #monitoring #secrets #cicd #dns
- **Related Nodes:** `VM-BASTION`, `SG-BASTION`, `SG-ASSOC-PILOT-VMS`, `INFRA-FIP`, `INFRA-TFCLOUD`, `INFRA-ANSIBLE`
- **Parent Nodes:** the current graph (roadmap hangs off it)
- **Child Nodes:** all `FW-*`, `RP-NGINX`, `VM-MERN-*`
- **Cross References:** [decisions.md](decisions.md) (revisit triggers), [vm-integration.md](vm-integration.md) (phase 3), [security-model.md](security-model.md) (80/443 + enforce)
- **Aliases:** feuille de route (fr), planned evolution, next phases
- **Infrastructure Layer:** `RP-NGINX`, `VM-MERN-*`, `FW-REVERSE-PROXY`
- **Networking Layer:** `FW-DOMAIN-DNS`, `FW-DNS-FIX`
- **Security Layer:** `FW-HTTPS`, `FW-VAULT`, `FW-ENFORCE-SG`
- **Terraform Layer:** `FW-PORT-AUTODISCOVERY`, `FW-CICD`
- **Operational Layer:** `FW-PROMETHEUS`, `FW-GRAFANA`, `FW-INVENTORY-AUTOMATION`
