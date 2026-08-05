# Feature: Operations Runbook (Procedures & Validation Ladder)

> Home document for: `OP-ADD-VM`, `OP-ATTACH-TO-BASTION`, `OP-RETRIEVE-PORT-ID`,
> `OP-ADD-SSH-KEY`, `OP-VERIFY-ACCESS`, `OP-REMOVE-VM`, `OP-CHANGE-ADMIN-CIDR`,
> `OP-ROLLBACK`, `OP-RUN-ANSIBLE`, `OP-DEPLOY-REVERSE-PROXY`,
> `OP-DISABLE-REVERSE-PROXY`, `DEPLOY-ROLLBACK`,
> `VAL-FMT`, `VAL-VALIDATE`, `VAL-PLAN`, `VAL-APPLY`, `VAL-SSH-BASTION`,
> `VAL-SSH-JUMP`, `VAL-ICMP-PRIVATE`, `VAL-SG-AUDIT`, `VAL-HARDENING`,
> `VAL-REVERSE-PROXY`

This is the executable layer of the graph. Each procedure lists its graph edges:
what it **configures**, what it **depends on**, and which **validations** prove it.

---

## Overview

- **Purpose:** Turn every recurring operational question ("add a VM", "add a key",
  "roll back") into a deterministic, validated procedure.
- **Context:** The infrastructure mixes Terraform-managed and legacy resources; most
  procedures are therefore *small Terraform edits + apply + verification*, never
  manual cloud surgery.
- **Problem solved:** Removes improvisation; every mutation is reproducible and
  reversible.
- **Why it exists:** `PRIN-IAC` applied to day-2 operations.

---

## The Validation Ladder (run bottom-up after any change)

| Order | Node | Command / check | Proves |
|---|---|---|---|
| 1 | `VAL-FMT` | `terraform fmt -check -diff` | style/normalization |
| 2 | `VAL-VALIDATE` | `terraform validate` | module syntax & types |
| 3 | `VAL-PLAN` | `terraform plan` — human review | intended diff only |
| 4 | `VAL-APPLY` | `terraform apply` exit 0 | change landed |
| 5 | `VAL-SG-AUDIT` | `openstack security group rule list <sg>`; `openstack port show <port> -c security_group_ids` | SG state correct |
| 6 | `VAL-SSH-BASTION` | `ssh ubuntu@<fip> true` | public path + bastion alive |
| 7 | `VAL-SSH-JUMP` | `ssh -J ubuntu@<fip> ubuntu@<vm-ip> hostname` | full two-hop path per VM |
| 8 | `VAL-ICMP-PRIVATE` | from bastion: `ping -c3 <vm-ip>`; from a VM: `ping -c3 <bastion-private-ip>` | ICMP rules both directions |
| 9 | `VAL-HARDENING` | on bastion: `systemctl is-active fail2ban auditd`; `sudo sshd -T \| grep -E 'passwordauthentication\|permitrootlogin\|allowagentforwarding'` → `no no no` | host hardening intact |
| 10 | `VAL-REVERSE-PROXY` | `sudo nginx -t`; `curl -H 'Host: <vhost>' http://<fip>/reverse-proxy-health` → `bastion-reverse-proxy-ok`; `curl -H 'Host: <vhost>' http://<fip>/` → app response | `RP-NGINX` serving vhosts |

**Negative controls (must FAIL):** SSH to a VM private IP from a laptop without `-J`;
SSH to the bastion from an IP outside `allowed_admin_cidrs`; password authentication
anywhere. A failure of a negative control = security regression, investigate before
proceeding.

---

## Operational Procedures

### `OP-ADD-VM` — Add a new VM to the private network

- **Purpose:** introduce a new workload VM into the graph.
- **Depends on:** `NET-PRIVATE` capacity; `OP-ATTACH-TO-BASTION` (step 3).
- **Configures:** (indirectly) `SG-ASSOC-PILOT-VMS`.
- **Steps:**
  1. Create the VM on `NET-PRIVATE` (Horizon: *Project → Compute → Instances → Launch
     Instance*, network = `reseau-stagiaires`; or CLI:
     `openstack server create --network reseau-stagiaires --image Ubuntu-22.04 --flavor <flavor> --key-name <key> <name>`).
     Do **not** attach a Floating IP (`DEC-007`).
  2. Record its fixed private IP (`openstack server show <name> -c addresses`).
  3. Attach it to the bastion model → `OP-ATTACH-TO-BASTION`.
  4. Add an SSH convenience output (`TFOUT-SSH-*`) and an `SSH-CONFIG` alias.
  5. `OP-VERIFY-ACCESS`.
- **Validation:** `VAL-SSH-JUMP` for the new VM; `VAL-SG-AUDIT` on its port.
- **Risks:** choosing a port/IP that collides with `ISSUE-HARDCODED-IPS` literals;
  forgetting step 4 leaves operators without a documented command.

### `OP-RETRIEVE-PORT-ID` — Retrieve a Neutron Port ID (Horizon or CLI)

- **Purpose:** obtain the `port_id` value required by `existing_vm_ports`
  (`SG-ASSOC-PILOT-VMS` input). Mitigates `ISSUE-MANUAL-PORT-ID`.
- **Depends on:** the VM existing on `NET-PRIVATE`.
- **Configures:** nothing (read-only lookup feeding `TFVAR-EXISTING-VM-PORTS`).
- **Steps (CLI — preferred):**
  1. `openstack port list --server <vm-name> -c ID -c fixed_ips`
  2. Verify the listed `fixed_ips` contains the VM's expected `192.168.100.x` address
     (**cross-check — this is what prevents protecting the wrong port**).
  3. Copy the `ID` (UUID).
- **Steps (Horizon):**
  1. *Project → Network → Networks* → click `reseau-stagiaires`.
  2. Open the **Ports** tab.
  3. Locate the port whose *Fixed IPs* match the VM's private IP (or whose attached
     device is the VM).
  4. Click the port → copy its **ID** from the overview panel.
- **Validation:** `openstack port show <uuid> -c fixed_ips -c device_owner` matches the VM.
- **Risks:** VM with multiple ports → one association per port needed; picking by name
  alone is unreliable (ports are often unnamed) — always match by IP.

### `OP-ATTACH-TO-BASTION` — Attach an existing VM to the bastion security model

- **Purpose:** extend `SG-PRIVATE-VMS` protection to a VM (part of `OP-ADD-VM`;
  also usable standalone for legacy VMs).
- **Depends on:** `OP-RETRIEVE-PORT-ID`.
- **Configures:** `SG-ASSOC-PILOT-VMS` via `TFVAR-EXISTING-VM-PORTS`.
- **Steps:**
  1. Edit `terraform.tfvars`: add `logical_name = "<PORT_UUID>"` inside
     `existing_vm_ports { … }` (follow `terraform.tfvars.example`; respect the phase
     gating of `DEC-005` for the four known VMs).
  2. `terraform plan` — expect exactly **one** new
     `openstack_networking_port_secgroup_associate_v2.tested_vms["logical_name"]`.
     Anything more = stop.
  3. `terraform apply`.
  4. `OP-VERIFY-ACCESS`.
- **Validation:** `VAL-SG-AUDIT` (port now lists `SG-PRIVATE-VMS` **plus** its legacy
  SGs — `DEC-004`), then `VAL-SSH-JUMP`.
- **Risks:** logical key rename later = association recreate (harmless but noisy);
  empty map destroys all associations.

### `OP-ADD-SSH-KEY` — Add an SSH public key to the bastion

- **Purpose:** grant a new admin access to the bastion (and thus, via their own VM
  keys, the fleet).
- **Depends on:** `SSH-DIRECT-BASTION` working for an existing admin.
- **Configures:** `VM-BASTION` authorized_keys (out-of-band, see warning).
- **⚠ Critical warning (`ISSUE-USERDATA-DRIFT`):** editing `admin_ssh_keys` in tfvars
  and applying does **nothing** — `user_data` changes are ignored after first boot
  (`DEC-003`). Use one of the two working paths:
- **Path A — Ansible (preferred, `PRIN-IAC`):**
  1. Extend `ansible/bastion-hardening.yml` with an `ansible.builtin.authorized_key`
     task for the `ubuntu` user (or a dedicated keys playbook).
  2. `OP-RUN-ANSIBLE`.
- **Path B — Manual (break-glass):**
  1. `ssh ubuntu@<fip>`
  2. Append the public key to `/home/ubuntu/.ssh/authorized_keys` (mode `600`,
     dir `700`).
  3. Also add the key to `admin_ssh_keys` in tfvars **for documentation/future
     rebuilds** — knowing it won't apply now.
- **Also required:** if the admin's source IP is new → `OP-CHANGE-ADMIN-CIDR`.
- **Validation:** new admin runs `VAL-SSH-BASTION` from their machine.
- **Risks:** manual path drifts from code (mitigate by recording the key in tfvars
  anyway); removing a key requires the same out-of-band edit.

### `OP-VERIFY-ACCESS` — Verify end-to-end access

- **Purpose:** the standard proof that a VM is correctly onboarded.
- **Depends on:** `OP-ATTACH-TO-BASTION` completed.
- **Uses:** `SSH-PROXYJUMP`.
- **Steps (per VM):**
  1. `VAL-SG-AUDIT` — `openstack port show <port-id> -c security_group_ids` includes
     `SG-PRIVATE-VMS`.
  2. `VAL-SSH-JUMP` — `ssh -J ubuntu@<fip> ubuntu@<vm-ip> 'hostname && whoami'`.
  3. `VAL-ICMP-PRIVATE` — from bastion `ping -c3 <vm-ip>`; from VM
     `ping -c3 <bastion-private-ip>`.
  4. Negative control — laptop direct `ssh ubuntu@<vm-ip>` times out.
- **Validation:** all four checks pass.
- **Risks:** skipping the negative control leaves silent legacy exposure undetected
  (pre-`FW-ENFORCE-SG` legacy SGs may legitimately allow other paths — record findings).

### `OP-REMOVE-VM` — Remove a VM from bastion control

- **Purpose:** detach a VM from the bastion security model (decommission or exclusion).
- **Configures:** `SG-ASSOC-PILOT-VMS`.
- **Steps:**
  1. Remove (or comment) the VM's entry from `existing_vm_ports` in `terraform.tfvars`.
  2. `terraform plan` — expect exactly one **destroy** of the association
     `…tested_vms["<logical_name>"]` and nothing else.
  3. `terraform apply` (only the added SG is detached; legacy SGs and the VM itself
     are untouched — `DEC-004` semantics).
  4. Remove the matching `TFOUT-SSH-*` output and `SSH-CONFIG` alias if permanent.
- **Validation:** `VAL-SG-AUDIT` (port no longer lists `SG-PRIVATE-VMS`);
  `VAL-SSH-JUMP` now **fails** for that VM (expected).
- **Risks:** if the VM's only working SSH path was the bastion, it becomes unreachable
  by design — confirm intent first.

### `OP-CHANGE-ADMIN-CIDR` — Change which admin IPs may reach the bastion

- **Purpose:** keep `SG-RULE-BASTION-SSH` aligned with where admins actually are.
- **Configures:** `SG-RULE-BASTION-SSH` via `TFVAR-ALLOWED-ADMIN-CIDR`.
- **Steps:**
  1. Edit `allowed_admin_cidrs` in tfvars (always `/32` per admin IP).
  2. **Keep your own current IP in the list** (lockout risk) — add before removing.
  3. `terraform plan` → in-place rule add/remove; `terraform apply` (instant, no
     instance impact).
- **Validation:** `VAL-SSH-BASTION` from each new CIDR; negative control from a
  removed CIDR.
- **Risks:** lockout if your IP changes between plan and apply (NAT/VPN churn);
  recovery requires cloud-side access (Horizon console) to fix tfvars→apply.

### `OP-RUN-ANSIBLE` — Re-apply bastion hardening with Ansible

- **Purpose:** steady-state configuration of `VM-BASTION` (`DEC-011`); the only
  supported post-boot change path (`DEC-003`).
- **Depends on:** `SSH-DIRECT-BASTION`; a local `ansible/inventory.ini` defining a
  `bastion` host/group (file is gitignored; `inventory.ini.example` is an empty
  template — `FW-INVENTORY-AUTOMATION`).
- **Uses:** `INFRA-ANSIBLE`.
- **Steps:**
  1. Create `ansible/inventory.ini`:
     `bastion ansible_host=<fip> ansible_user=ubuntu`
  2. `ansible-playbook -i ansible/inventory.ini ansible/bastion-hardening.yml`
  3. Re-run must converge (`changed=0` when no drift).
- **Validation:** `VAL-HARDENING`.
- **Risks:** playbook ↔ cloud-init drift if only one is edited (mirror rule:
  any hardening change goes in **both** files).

### `OP-DEPLOY-REVERSE-PROXY` — Deploy / update the Nginx reverse proxy (`RP-NGINX`)

- **Purpose:** publish (or update) a web vhost on the bastion toward a private VM —
  executed 2026-08-03 for `RP-VHOST-JAVAJS` (pass 1 HTTP) and 2026-08-04 for
  `RP-VHOST-FULLSTACK` (multi-vhost live).
- **Depends on:** `SG-RULE-BASTION-HTTP`/`SG-RULE-BASTION-HTTPS` applied;
  `SSH-DIRECT-BASTION`; upstream reachable from the bastion
  (`curl -I http://<vm-ip>:<port>`).
- **Configures:** `RP-NGINX` + its vhosts (Ansible, `DEC-011` path — no Terraform).
  One `reverse_proxy_*` variable set per site (domain + upstream); re-running the
  playbook adds the vhost idempotently without disturbing the others.
- **Steps:**
  1. Set variables in `ansible/group_vars/bastion.yml`
     (`reverse_proxy_domain`, `reverse_proxy_upstream_host/port`,
     `reverse_proxy_enable_https`).
  2. `cd ansible && ansible bastion -m ping`.
  3. `ansible-playbook playbooks/bastion-reverse-proxy.yml --syntax-check`.
  4. `ansible-playbook playbooks/bastion-reverse-proxy.yml` (idempotent; the role
     validates upstream, health endpoint and — when DNS is live — public HTTP(S)).
  5. **Pass 2 (HTTPS, `FW-HTTPS`):** once the DNS record resolves to `INFRA-FIP`,
     set `reverse_proxy_enable_https: true` + real `certbot_email` in
     `ansible/group_vars/bastion.yml`, re-run the same playbook. The role issues the
     cert (`certonly --webroot`, no nginx rewrite) and re-renders the vhost in TLS
     mode in the same run. `duckdns_ip` must equal the bastion's *entrance* IP
     (`188.40.148.152`), not its egress IP.
- **Validation:** `VAL-REVERSE-PROXY`.
- **Risks:** a failed first run before handler flush can leave the vhost written but
  never reloaded — fixed in-role with `meta: flush_handlers` before validation;
  ansible-core ≥ 2.21 rejects handlers built as a top-level `block:` (use chained
  handlers, see `roles/reverse_proxy/handlers/main.yml`); the bastion's resolver
  intermittently drops the first lookup of a new name — certbot dry-run uses
  `--no-random-sleep-on-renew` + retries, and DuckDNS/curl use `--retry` to survive it.
  - **2026-08-05 (Open edX `RP-VHOST-OPENEDX`):** Certbot issuance initially failed
    with `Network is unreachable` because the bastion has **no IPv6 route** and
    certbot 1.21 picks the AAAA record. Persistent fix:
    `precedence ::ffff:0:0/96  100` in `/etc/gai.conf` (forces IPv4 for ACME
    issuance *and* the `certbot.timer` renewals). Add the gai.conf line on any new
    bastion before enabling HTTPS for a new vhost.

### `OP-DISABLE-REVERSE-PROXY` — Disable a reverse-proxy vhost (rollback)

- **Purpose:** unpublish a vhost without touching the backend VM or its data.
- **Configures:** `RP-NGINX` (removes the `sites-enabled` symlink only).
- **Steps:** `ansible-playbook playbooks/disable-reverse-proxy.yml` (optionally
  `-e reverse_proxy_site_name=<name>`), or manually on the bastion:
  `sudo rm /etc/nginx/sites-enabled/<site> && sudo nginx -t && sudo systemctl reload nginx`.
- **Validation:** `curl -H 'Host: <vhost>' http://<fip>/` no longer serves the app;
  upstream VM untouched.
- **Risks:** none beyond the intended unpublishing; the TLS certs in
  `/etc/letsencrypt` are kept for re-enablement.

### `VAL-REVERSE-PROXY` — Reverse proxy validation

- **Purpose:** prove `RP-NGINX` serves correct backends per vhost (multi-vhost since 2026-08-04).
- **Steps (from any machine):**
  1. For each vhost: `curl -s -H 'Host: <vhost>' http://188.40.148.152/reverse-proxy-health`
     → `bastion-reverse-proxy-ok` (check `rif-javajs.duckdns.org` **and** `rif-fullstack.duckdns.org`).
  2. `curl -sL -H 'Host: <vhost>' http://188.40.148.152/` → HTML of the SPA
     (`rif-javajs` → `<title>Shadcn Admin</title>`; `rif-fullstack` → `<title>MatchJob …</title>`);
     over the public domain it first answers `301 → https`.
  3. `curl -s -o /dev/null -w '%{http_code}' https://rif-javajs.duckdns.org/auth/authenticate`
     → `401`/`403` (backend path proxied, not the SPA fallback).
     `curl -s -o /dev/null -w '%{http_code}' https://rif-fullstack.duckdns.org/api/companies`
     → `200` (backend proxied, not the SPA fallback).
  4. On the bastion: `sudo nginx -t` → syntax ok.
- **Pass 2 additions:** `curl -I https://rif-javajs.duckdns.org` → 200, valid LE
  chain (`subject=CN=rif-javajs.duckdns.org`, `Verify return code: 0`);
  `sudo certbot renew --dry-run`; `systemctl is-active certbot.timer`;
  `sudo crontab -l` shows the DuckDNS cron (`*/5 * * * * /opt/duckdns/update.sh`).
- **Validates:** `RP-NGINX`, `RP-VHOST-JAVAJS`, `RP-VHOST-FULLSTACK`, `SG-RULE-BASTION-HTTP(S)`.

### `OP-ROLLBACK` — Roll back a Terraform change (`DEPLOY-ROLLBACK`)

- **Purpose:** return the graph to its last good state.
- **Uses:** `DEPLOY-ROLLBACK` (supersedes a bad `DEPLOY-APPLY`).
- **Steps:**
  1. **Code-level (default):** `git revert <bad-commit>` (or checkout last-good),
     `terraform plan` (expect the inverse diff), `terraform apply`.
  2. **Association-only accidents:** remove the offending `existing_vm_ports` entry,
     apply (see `OP-REMOVE-VM`).
  3. **State-level (exceptional):** in the Terraform Cloud workspace, roll back to a
     previous state version, then `terraform plan` to converge reality↔state.
- **Destroying the bastion (rare, sanctioned path):** `prevent_destroy` (`DEC-002`)
  blocks it. Procedure: remove the `lifecycle { prevent_destroy = true }` blocks from
  `bastion.tf` → apply (destroys port+instance; **the FIP survives**, `DEC-001`) →
  restore blocks → apply to recreate → `OP-RUN-ANSIBLE` → full validation ladder.
- **Validation:** post-rollback full ladder (all `VAL-*`).
- **Risks:** state rollback while reality drifted = confusing plans; prefer
  code-level rollback always.

### `ISSUE-AUTH-403-502` — Public sign-in/sign-up broken on both sites (2026-08-04)

- **Symptom:** `https://rif-javajs.duckdns.org` → `403 Invalid CORS request` on
  register/login; `https://rif-fullstack.duckdns.org` → `502 Bad Gateway` on every
  `/api/*` call. Repo unchanged; both apps healthy locally on their VMs.
- **Root causes (two independent VM-side defects):**
  1. **rif-javajs 403 — CORS allowlist.** The api-gateway container env
     `APP_CORS_ALLOWED_ORIGINS` (`docker-compose.yml` on `VM-JAVA-JS`, line ~156)
     only allowed `http://localhost:3030` + `:5173`, so the gateway's CORS filter
     rejected the public origin. Fix: append
     `,https://rif-javajs.duckdns.org,http://rif-javajs.duckdns.org`, then
     `docker compose up -d --no-deps api-gateway` (backup `.bak.*` kept). Preflight
     now returns `access-control-allow-origin: https://rif-javajs.duckdns.org`.
  2. **rif-javajs backend crash-loop — missing `mongodb`.** The `mongodb` container
     was absent; user-service had RestartCount ≈ 10 k. After pulling `mongo:7`
     (Docker Hub egress on this VM is intermittently broken — retry), run
     `docker compose up -d mongodb` then `docker compose up -d user-service` → healthy.
  3. **rif-fullstack 502 — WebSocket upgrade headers on every request.** The VM's
     nginx `/api/` block set `proxy_set_header Upgrade $forwarded_proto;` and
     `proxy_set_header Connection "upgrade";` on all requests; the backend closes the
     connection → `upstream prematurely closed connection`. Fix: delete both lines in
     `/opt/fullstack-js/deploy/nginx/default.conf` (backup `.bak.*` kept) and
     **restart the nginx container** (`docker-compose restart sovereignscale-nginx`) —
     it is a `:ro` bind-mount, so a bare `nginx -s reload` did not pick up the edit.
- **Validation:** both `reverse-proxy-health` endpoints → `bastion-reverse-proxy-ok`;
  `curl -s -o /dev/null -w '%{http_code}' https://rif-javajs.duckdns.org/auth/register`
  → 200 (was 403); `curl -s -o /dev/null -w '%{http_code}'
  https://rif-fullstack.duckdns.org/api/companies` → 200 (was 502).
- **Known app-level follow-ups (transport is now correct):**
  - rif-javajs login: `/auth/authenticate` returns 401 even for a just-registered
    user with correct credentials (register → 200 + JWT). Likely bcrypt compare /
    Mongo DB selection: the backend writes to the default `test` db even though the
    URI is `mongodb://mongodb:27017/user` → lookup fails. Needs a source fix in
    user-microservice (image-only on the VM; no source).
  - rif-fullstack login: HTTPS `/api/auth/login` returns
    `401 {"message":"Validation Cloudflare échouée…"}` when no Turnstile token is
    sent — expected without a browser; fine from the real UI.
- **Related:** `RP-VHOST-JAVAJS`, `RP-VHOST-FULLSTACK`, `VM-JAVA-JS`, `VM-FULL-STACK-JS`,
  `VAL-REVERSE-PROXY`.

---

## Graph Relationships (local view)

```
OP-ADD-VM           DEPENDS_ON  OP-RETRIEVE-PORT-ID
OP-ATTACH-TO-BASTION PART_OF    OP-ADD-VM
OP-ATTACH-TO-BASTION CONFIGURES SG-ASSOC-PILOT-VMS
OP-RETRIEVE-PORT-ID RELATED_TO  ISSUE-MANUAL-PORT-ID
OP-ADD-SSH-KEY      RELATED_TO  ISSUE-USERDATA-DRIFT
OP-ADD-SSH-KEY      USES        OP-RUN-ANSIBLE              (preferred path)
OP-VERIFY-ACCESS    USES        SSH-PROXYJUMP
OP-VERIFY-ACCESS    USES        VAL-SG-AUDIT · VAL-SSH-JUMP · VAL-ICMP-PRIVATE
OP-REMOVE-VM        CONFIGURES  SG-ASSOC-PILOT-VMS
OP-CHANGE-ADMIN-CIDR CONFIGURES SG-RULE-BASTION-SSH
OP-ROLLBACK         USES        DEPLOY-ROLLBACK
DEPLOY-ROLLBACK     SUPERSEDES  DEPLOY-APPLY
OP-RUN-ANSIBLE      USES        INFRA-ANSIBLE
OP-DEPLOY-REVERSE-PROXY CONFIGURES RP-NGINX
OP-DEPLOY-REVERSE-PROXY DEPENDS_ON SG-RULE-BASTION-HTTP · SG-RULE-BASTION-HTTPS
OP-DISABLE-REVERSE-PROXY CONFIGURES RP-NGINX
VAL-REVERSE-PROXY   VALIDATES   RP-NGINX · RP-VHOST-JAVAJS
VAL-VALIDATE/PLAN   VALIDATES   TFMOD-ROOT
VAL-SSH-BASTION     VALIDATES   VM-BASTION · SG-BASTION
VAL-SSH-JUMP        VALIDATES   SG-PRIVATE-VMS · SG-ASSOC-PILOT-VMS
VAL-ICMP-PRIVATE    VALIDATES   SG-RULE-BASTION-ICMP · SG-RULE-VM-ICMP-FROM-BASTION
VAL-SG-AUDIT        VALIDATES   SG-* · SG-ASSOC-PILOT-VMS
VAL-HARDENING       VALIDATES   INFRA-CLOUDINIT · INFRA-ANSIBLE
```

---

## Decisions (canonical text in [decisions.md](decisions.md))

`DEC-002` (rollback must be deliberate), `DEC-003` (Ansible is the change path),
`DEC-004` (remove ≠ unprotect legacy), `DEC-005` (phase gating).

---

## Terraform Knowledge

Procedures mutate exactly two inputs: `existing_vm_ports` (attach/remove) and
`allowed_admin_cidrs` (admin IPs). Both are in-place operations with narrow,
predictable plans — if `plan` shows anything else, stop.

---

## Infrastructure Workflow

Standard loop: branch → edit tfvars/`.tf` → validation ladder steps 1–4 →
feature-specific `OP-*` → validation ladder steps 5–9 → commit.

---

## Validation

The ladder at the top of this document is the canonical validation definition;
feature documents reference it by node ID (`VAL-*`).

---

## Future Roadmap

- `FW-CICD` — run ladder steps 1–4 in CI; steps 5–9 as smoke tests.
- `FW-INVENTORY-AUTOMATION` — remove the manual inventory step of `OP-RUN-ANSIBLE`.
- `FW-PORT-AUTODISCOVERY` — collapse `OP-RETRIEVE-PORT-ID` into a data source.
- `FW-VAULT` — replace `OP-ADD-SSH-KEY` with short-lived certificates.

---

## AI Retrieval Optimization

- **Keywords:** runbook, add VM, attach VM to bastion, retrieve port ID, Horizon port ID, openstack port list --server, add SSH key, authorized_keys, verify access, remove VM, rollback, git revert apply, change admin CIDR, allowed IP, ansible-playbook inventory, validation ladder, negative control
- **Tags:** #operations #runbook #procedures #validation #day2
- **Related Nodes:** all `SG-*`, all `VM-*`, `TFVAR-EXISTING-VM-PORTS`, `TFVAR-ALLOWED-ADMIN-CIDR`, `INFRA-ANSIBLE`
- **Parent Nodes:** `PRIN-IAC`, `DEC-002..005`
- **Child Nodes:** all `OP-*`, all `VAL-*`, `DEPLOY-ROLLBACK`
- **Cross References:** every feature document (this is the executable hub)
- **Aliases:** procédures opérationnelles (fr), day-2 operations, SRE runbook, validation checklist
- **Infrastructure Layer:** touched via OpenStack CLI checks
- **Networking Layer:** port lookups, ICMP checks
- **Security Layer:** SG audits, key management, negative controls
- **Terraform Layer:** plan/apply loops, rollback
- **Operational Layer:** everything in this document
