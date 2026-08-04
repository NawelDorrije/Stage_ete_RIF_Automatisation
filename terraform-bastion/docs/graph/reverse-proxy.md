# Feature: Reverse Proxy (Nginx on the Bastion)

> Home document for: `RP-NGINX`, `RP-VHOST-JAVAJS`, `RP-VHOST-FULLSTACK`
>
> Graduated from [future-roadmap.md](future-roadmap.md) on 2026-08-03 (pass 1 HTTP
> implemented for the Java-JS vhost; HTTPS pass 2 tracked by `FW-HTTPS`).
> Multi-vhost (second site `rif-fullstack`) live 2026-08-04.

---

## Overview

- **Purpose:** The bastion terminates public HTTP(S) and forwards to application VMs
  on `NET-PRIVATE` — extending `PRIN-SINGLE-ENTRY` / `DEC-007` from SSH to user web
  traffic. No application VM needs a Floating IP to serve users.
- **Context:** Implemented with the Ansible role `reverse_proxy` (pattern reused from
  the Full-Stack-JS deployment doc, adapted to Java-JS / DakarCitoyen, then extended
  to a second vhost for the Full-Stack-JS / MatchJob site).
- **Problem solved:** Users reach hosted apps by name over the single bastion FIP
  (`INFRA-FIP`), which multiplexes SSH/22 + HTTP/80 + HTTPS/443.
- **Vhosts (both live 2026-08-04):**
  - `rif-javajs.duckdns.org` → `http://192.168.100.149:80` — **Shadcn Admin
    (DakarCitoyen)** frontend; the frontend container itself proxies `/auth/*` to the
    Spring backend, so a single upstream suffices (verified 2026-08-03).
  - `rif-fullstack.duckdns.org` → `http://192.168.100.87:80` — **MatchJob** frontend;
    the VM's own nginx proxies `/api/*` to the backend container (port 5000), so a
    single upstream suffices.

### Traffic flow

```
Internet ── tcp/80,443 ─▶ INFRA-FIP (188.40.148.152) ─▶ VM-BASTION : Nginx
                                                              │ proxy_pass (private net)
                                                              ├▶ VM-JAVA-JS 192.168.100.149:80
                                                              │   (frontend container → Spring API interne)
                                                              └▶ VM-FULL-STACK-JS 192.168.100.87:80
                                                                  (nginx → frontend + backend:5000)
```

---

## Graph Nodes

### `RP-NGINX` — Nginx reverse proxy on the bastion

- **Type:** Reverse Proxy · **Layer:** Infrastructure + Security · **Status:** **implemented (HTTP + HTTPS)** — pass 2 (HTTPS) deployed 2026-08-03
- **Description:** Nginx (package) on `VM-BASTION`, configured by the Ansible role
  `reverse_proxy` in `ansible/roles/reverse_proxy/` (tasks: nginx, firewall/UFW,
  optional duckdns, optional certbot, validate). Hardening drop-in
  `/etc/nginx/conf.d/99-reverse-proxy-hardening.conf` (`server_tokens off`, rate/conn
  limit zones, header buffers, timeouts). Reload is guarded: handler chain
  `Tester la syntaxe Nginx` → `Recharger Nginx` (nginx -t gates every reload).
- **Purpose:** Single public web entry; app ports never exposed publicly.
- **Dependencies:** `VM-BASTION`, `SG-RULE-BASTION-HTTP`, `SG-RULE-BASTION-HTTPS`,
  `INFRA-FIP` (same public IP multiplexes SSH + HTTP(S)).
- **Related Components:** `RP-VHOST-JAVAJS`, `RP-VHOST-FULLSTACK` (live vhosts),
  `FW-HTTPS` (TLS pass 2), `INFRA-ANSIBLE` (same automation path, `DEC-011`).
- **Files involved:** `ansible/playbooks/bastion-reverse-proxy.yml`,
  `ansible/playbooks/disable-reverse-proxy.yml`, `ansible/roles/reverse_proxy/**`,
  `ansible/group_vars/bastion.yml`, `ansible/inventory.ini`.
- **Commands:** `sudo nginx -t`; `sudo nginx -T`; `systemctl status nginx`.
- **Validation procedure:** `VAL-REVERSE-PROXY` (→ See: [operations.md](operations.md)).
- **Risks:** bastion SPOF now also gates user traffic; sizing of `INFRA-FLAVOR`
  (1 vCPU/4 GB) to revisit if vhosts multiply.
- **Future improvements:** additional vhosts (LMS, Odoo, Gitea) as subdomains; WAF
  rules; HA pair.
- **Implements:** `FW-REVERSE-PROXY` (E123).
- **Note (ansible-core ≥ 2.21):** a handler whose body is a top-level `block:` is
  no longer registered — the original doc pattern was split into two chained
  handlers. Also `meta: flush_handlers` runs before validation so a failed first
  run can't leave the vhost deployed-but-never-reloaded.
- **TLS design (since pass 2):** the vhost template (`reverse-proxy.conf.j2`) is the
  *sole* owner of the nginx config — it renders the `443 ssl http2` server block and
  the `80 → 301 https` redirect when `reverse_proxy_tls_enabled` is true (HTTPS on
  **and** cert present). Certbot runs in `certonly --webroot` mode (webroot
  `/var/www/certbot`, ACME challenge served by `location /.well-known/acme-challenge/`
  on port 80) and **never edits nginx** — so the template and certbot no longer fight.
  On a fresh run the role first deploys the HTTP-only vhost, issues the cert, then
  re-deploys the vhost with TLS (two-phase), all in one playbook run.
- **DuckDNS:** record is pinned to the bastion *entrance* IP (`duckdns_ip`,
  `188.40.148.152`) because the bastion's egress IP differs (FIP is DNAT-only, egress
  is `195.201.169.165`) — auto-detection via `ip=` would point the record at the
  wrong host. Cron `/opt/duckdns/update.sh` every 5 min keeps it in sync; the script
  now uses `--max-time/--retry` to survive the bastion's intermittent DNS drops.

### `RP-VHOST-JAVAJS` — vhost `rif-javajs.duckdns.org` → Java-JS

- **Type:** Reverse Proxy (vhost) · **Layer:** Infrastructure + Networking · **Status:** implemented (HTTP + HTTPS)
- **Description:** `/etc/nginx/sites-available/rif-javajs` (enabled symlink);
  upstream block `javajs_application` = `192.168.100.149:80` (keepalive 32);
  full `X-Forwarded-*` header set; WebSocket upgrade map; `client_max_body_size 20m`;
  local health endpoint `GET /reverse-proxy-health` → `200 bastion-reverse-proxy-ok`;
  since pass 2 also `listen 443 ssl http2` with the Let's Encrypt cert and HTTP→HTTPS
  redirect (except `/.well-known/acme-challenge/`).
- **Purpose:** Publish the DakarCitoyen frontend (and its `/auth` API path, proxied
  by the frontend container itself) without touching `VM-JAVA-JS`.
- **Dependencies:** `RP-NGINX`, `VM-JAVA-JS`, `NET-PRIVATE` reachability;
  public DNS (DuckDNS record → `INFRA-FIP`, kept in sync by the role's cron).
- **Related Components:** `FW-HTTPS` (TLS now live; the vhost is rendered by the
  template, certbot `certonly --webroot` only manages certificates).
- **Files involved:** `ansible/roles/reverse_proxy/templates/reverse-proxy.conf.j2`,
  `ansible/group_vars/bastion.yml` (`reverse_proxy_*` variables).
- **Commands:** `curl -H 'Host: rif-javajs.duckdns.org' http://188.40.148.152/reverse-proxy-health`;
  `curl -I https://rif-javajs.duckdns.org`.
- **Validation procedure:** `VAL-REVERSE-PROXY`; browser reaches the "Shadcn Admin"
  SPA over HTTPS; `/auth/authenticate` returns 401/403 (backend reachable, not the
  SPA fallback — 403 is the Spring Security response to an unauthenticated call;
  401 with valid creds is a known app-level bug, see `ISSUE-AUTH-403-502`).
- **Runbook notes (2026-08-04):** public calls returned
  `403 Invalid CORS request` because the api-gateway env
  `APP_CORS_ALLOWED_ORIGINS` (`docker-compose.yml` on `VM-JAVA-JS`, line ~156) only
  allowed `http://localhost:3030` + `:5173`. Fixed by appending
  `,https://rif-javajs.duckdns.org,http://rif-javajs.duckdns.org` and
  `docker compose up -d --no-deps api-gateway` (backup `.bak.*` kept). Preflight now
  returns `access-control-allow-origin: https://rif-javajs.duckdns.org`.
- **Risks:** DNS record is operator-created but cron-maintained by the role — if the
  cron or the `duckdns_ip` value lapses, ACME renewal fails; UFW on `VM-JAVA-JS` must
  keep allowing tcp/80 from the private network.
- **Future improvements:** `gitea.*` / `chat.*` vhosts on the same FIP; restrict
  Gitea's direct port 3000 once vhosts cover it.

### `RP-VHOST-FULLSTACK` — vhost `rif-fullstack.duckdns.org` → Full-Stack-JS

- **Type:** Reverse Proxy (vhost) · **Layer:** Infrastructure + Networking · **Status:** implemented (HTTP + HTTPS), live 2026-08-04
- **Description:** `/etc/nginx/sites-available/rif-fullstack` (enabled symlink);
  upstream block `fullstack_application` = `192.168.100.87:80` (keepalive 32);
  full `X-Forwarded-*` header set; WebSocket upgrade map; `client_max_body_size 20m`;
  local health endpoint `GET /reverse-proxy-health` → `200 bastion-reverse-proxy-ok`;
  `listen 443 ssl http2` with the Let's Encrypt cert and HTTP→HTTPS redirect (except
  `/.well-known/acme-challenge/`).
- **Purpose:** Publish the MatchJob frontend and its `/api` path (proxied by the VM's
  nginx to the backend container, port 5000) without touching `VM-FULL-STACK-JS`.
- **Dependencies:** `RP-NGINX`, `VM-FULL-STACK-JS`, `NET-PRIVATE` reachability;
  public DNS (DuckDNS record → `INFRA-FIP`, kept in sync by the role's cron).
- **Files involved:** `ansible/roles/reverse_proxy/templates/reverse-proxy.conf.j2`,
  `ansible/group_vars/bastion.yml` (`reverse_proxy_*` variables).
- **Commands:** `curl -H 'Host: rif-fullstack.duckdns.org' http://188.40.148.152/reverse-proxy-health`;
  `curl -I https://rif-fullstack.duckdns.org`.
- **Validation procedure:** `VAL-REVERSE-PROXY`; browser reaches the "MatchJob" SPA
  over HTTPS; `/api/auth/login` → 400/401 JSON (backend proxied, not SPA fallback).
- **Runbook notes (2026-08-04):** public calls returned `502 upstream prematurely
  closed` — the VM's nginx `/api/` block sent `proxy_set_header Upgrade $forwarded_proto;`
  and `proxy_set_header Connection "upgrade";` on *every* request, so the backend
  closed the connection. Fixed by deleting both lines in
  `/opt/fullstack-js/deploy/nginx/default.conf` (backup `.bak.*` kept) and
  `docker-compose restart sovereignscale-nginx` — the file is a `:ro` bind-mount, so
  a bare `nginx -s reload` did **not** pick up the edit.
- **Risks:** same as `RP-VHOST-JAVAJS` (DNS/ACME lapse; UFW on `VM-FULL-STACK-JS`
  must keep allowing tcp/80 from the private network).
- **Future improvements:** same as `RP-VHOST-JAVAJS`.

---

## Graph Relationships (new edges)

```
RP-NGINX        DEPENDS_ON   VM-BASTION
RP-NGINX        USES         SG-RULE-BASTION-HTTP · SG-RULE-BASTION-HTTPS
RP-VHOST-JAVAJS PART_OF      RP-NGINX
RP-VHOST-JAVAJS CONNECTS_TO  VM-JAVA-JS            (upstream 192.168.100.149:80)
RP-VHOST-JAVAJS EXPOSES      VM-JAVA-JS            (web traffic only; no FIP on the VM)
RP-VHOST-FULLSTACK PART_OF   RP-NGINX
RP-VHOST-FULLSTACK CONNECTS_TO VM-FULL-STACK-JS    (upstream 192.168.100.87:80)
RP-VHOST-FULLSTACK EXPOSES   VM-FULL-STACK-JS      (web traffic only; no FIP on the VM)
ISSUE-AUTH-403-502 RELATED_TO RP-VHOST-JAVAJS · RP-VHOST-FULLSTACK
```

---

## AI Retrieval Optimization

- **Keywords:** reverse proxy, nginx, vhost, rif-javajs, rif-fullstack, duckdns, dakarcitoyen, matchjob, java-js, full-stack-js, 192.168.100.149, 192.168.100.87, upstream, x-forwarded, websocket, health check, bastion web entry, CORS, 403, 502
- **Tags:** #reverse-proxy #nginx #java-js #full-stack-js #http #implemented
- **Related Nodes:** `VM-BASTION`, `VM-JAVA-JS`, `VM-FULL-STACK-JS`, `SG-BASTION`, `SG-RULE-BASTION-HTTP`, `SG-RULE-BASTION-HTTPS`, `INFRA-FIP`, `FW-HTTPS`, `FW-DOMAIN-DNS`, `INFRA-ANSIBLE`, `ISSUE-AUTH-403-502`
- **Parent Nodes:** `VM-BASTION` (host), `FW-REVERSE-PROXY` (capability)
- **Child Nodes:** `RP-VHOST-JAVAJS`, `RP-VHOST-FULLSTACK`
- **Cross References:** [security-model.md](security-model.md) (80/443 rules), [operations.md](operations.md) (deploy/disable/validate, incident runbook), [future-roadmap.md](future-roadmap.md) (`FW-HTTPS` pass 2)
- **Aliases:** proxy inverse (fr), point d'entrée web, nginx bastion
- **Infrastructure Layer:** `RP-NGINX`, `RP-VHOST-JAVAJS`, `RP-VHOST-FULLSTACK`
- **Networking Layer:** `RP-VHOST-JAVAJS`, `RP-VHOST-FULLSTACK`
- **Security Layer:** `RP-NGINX`
