# Feature: Networking Topology

> Home document for: `NET-PRIVATE`, `NET-PRIVATE-SUBNET`, `NET-EXTERNAL`,
> `INFRA-OPENSTACK`, `INFRA-OPENSTACK-ENDPOINTS`, `ISSUE-LOCALHOST-ENDPOINTS`, `ISSUE-DNS`

---

## Overview

- **Purpose:** Describe the network substrate every other component attaches to:
  one private tenant network carrying all VMs, one external provider network carrying
  the single Floating IP, and the local OpenStack control plane Terraform talks to.
- **Context:** All pre-existing training VMs already live on `reseau-stagiaires`
  (`192.168.100.0/24`). The bastion joins the same L2 domain so it can reach them
  without routing through the public side.
- **Problem solved:** Gives internal VMs full lateral reachability **without** any of
  them holding a public address; only the bastion straddles both worlds.
- **Why it exists:** Network layout is the physical enforcement of `PRIN-MIN-EXPOSURE`;
  SGs (`security-model.md`) are the logical enforcement on top of it.

---

## Architecture

### Topology

```
                         ┌──────────────────────────────┐
                         │   NET-EXTERNAL ("public")    │
                         │   INFRA-FIP  ◄── allocated   │
                         └──────────────┬───────────────┘
                                        │ INFRA-FIP-ASSOC (DNAT)
┌───────────────────────────────────────┼──────────────────────────────┐
│ NET-PRIVATE ("reseau-stagiaires")     │                              │
│ NET-PRIVATE-SUBNET 192.168.100.0/24   │                              │
│                                       │                              │
│   INFRA-BASTION-PORT ◄────────────────┘        VM-LMS-OPENEDX  .55   │
│   └─ VM-BASTION                                VM-ODOO-SERVER  .91   │
│                                                VM-FULL-STACK-JS .87  │
│                                                VM-JAVA-JS      .149  │
└──────────────────────────────────────────────────────────────────────┘

Control plane: TFMOD-ROOT ──HTTPS──> INFRA-OPENSTACK-ENDPOINTS (127.0.0.1:5000/8774/9696/19292/8776)
```

### Data flow

1. **Inbound admin traffic:** admin → `INFRA-FIP` (public) → Neutron DNAT →
   `INFRA-BASTION-PORT` (private) → `VM-BASTION` sshd.
2. **East-west admin traffic:** bastion → private subnet → VM sshd (port 22), permitted
   by `SG-PRIVATE-VMS` only when the source port carries `SG-BASTION`.
3. **Control-plane traffic:** Terraform → Keystone/Nova/Neutron/Glance/Cinder on
   `127.0.0.1` endpoints (`DEC-012`).

### Security boundaries

- **Boundary A — Internet↔cloud:** `NET-EXTERNAL`; crossed only by `INFRA-FIP`.
- **Boundary B — FIP↔bastion port:** enforced by `SG-BASTION` (CIDR-restricted SSH/22).
- **Boundary C — bastion↔internal VMs:** enforced by `SG-PRIVATE-VMS` (`remote_group_id`).
- **Boundary D — operator↔control plane:** whoever can reach `127.0.0.1` endpoints with
  valid credentials controls the cloud (`ISSUE-LOCALHOST-ENDPOINTS`).

---

## Graph Nodes

### `NET-PRIVATE` — Private Network `reseau-stagiaires`

- **Type:** Network · **Layer:** Networking
- **Description:** Pre-existing tenant network hosting every VM of the project.
  Referenced read-only via `TFDATA-PRIVATE-NETWORK` (never managed — `PRIN-NON-DESTRUCTIVE-TESTING`).
- **Purpose:** Shared L2/L3 domain for bastion-to-VM traffic.
- **Dependencies:** `INFRA-OPENSTACK`.
- **Related Components:** `NET-PRIVATE-SUBNET` (part of it), all `VM-*`,
  `INFRA-BASTION-PORT`, `SG-RULE-BASTION-ICMP` (CIDR derived from it).
- **Files involved:** `data.tf`, `variables.tf` (`private_network_name`, default `reseau-stagiaires`).
- **Commands:** `openstack network show reseau-stagiaires`.
- **Validation procedure:** network exists, `admin_state_up`, contains subnet `subnet-stagiaires`.
- **Risks:** single shared network = flat trust domain; any VM compromise is one hop
  from the others (mitigated by SGs only).
- **Future improvements:** per-role networks/VLANs if workload isolation grows;
  `FW-DNS-FIX` for name resolution inside it.

### `NET-PRIVATE-SUBNET` — Subnet `subnet-stagiaires` (`192.168.100.0/24`)

- **Type:** Network · **Layer:** Networking
- **Description:** IPv4 subnet of `NET-PRIVATE`; source of the bastion port `fixed_ip`
  and of every VM's address (`.55` LMS, `.87` Full-Stack-JS, `.91` Odoo, `.149` Java-JS).
- **Purpose:** Addressing plan; its CIDR is hardcoded in `SG-RULE-BASTION-ICMP`.
- **Dependencies:** `NET-PRIVATE`.
- **Related Components:** `TFDATA-PRIVATE-SUBNET`, `INFRA-BASTION-PORT`,
  `ISSUE-HARDCODED-IPS` (outputs mirror its addresses).
- **Files involved:** `data.tf`, `variables.tf` (`private_subnet_name`), `security-groups.tf` (CIDR literal).
- **Commands:** `openstack subnet show subnet-stagiaires`.
- **Validation procedure:** CIDR is `192.168.100.0/24`, DHCP/allocation pools healthy.
- **Risks:** CIDR literal duplicated in SG rule → drift if subnet is ever renumbered.
- **Future improvements:** parameterize the CIDR as a variable consumed by both SG rules.

### `NET-EXTERNAL` — External Network `public`

- **Type:** Network · **Layer:** Networking
- **Description:** Provider network from which `INFRA-FIP` was allocated. Looked up via
  `TFDATA-EXTERNAL-NETWORK` (currently unused by active resources — kept for the day the
  commented-out managed FIP returns, see `DEC-001`/`ISSUE-ORPHAN-FIP-SUBNET-VAR`).
- **Purpose:** Public address pool; the only ingress from outside.
- **Dependencies:** `INFRA-OPENSTACK`.
- **Related Components:** `INFRA-FIP`, `TFVAR-EXTERNAL-NETWORK-NAME`,
  `TFVAR-FLOATING-IP-SUBNET-ID`.
- **Files involved:** `data.tf`, `variables.tf`, `terraform.tfvars.example`
  (mentions candidate public subnets `subnet-public-188` / `subnet-public-routed`).
- **Commands:** `openstack network show public`, `openstack subnet list --network public`.
- **Validation procedure:** network `external: true`, reachable router, FIP pool available.
- **Risks:** any future managed FIP must pick the correct public subnet (see
  `ISSUE-ORPHAN-FIP-SUBNET-VAR`).
- **Future improvements:** `FW-DOMAIN-DNS` + `FW-HTTPS` will terminate here (via bastion).

### `INFRA-OPENSTACK` — OpenStack Cloud (local, RegionOne)

- **Type:** Infrastructure Component · **Layer:** Infrastructure
- **Description:** The cloud itself. Region `RegionOne`; Identity v3 auth with
  username/password/tenant; service catalog overridden to localhost endpoints
  (`INFRA-OPENSTACK-ENDPOINTS`). Profile matches a single-node/all-in-one deployment
  (DevStack-style) rather than a public cloud.
- **Purpose:** Compute/network/image/volume provider for the whole graph.
- **Dependencies:** none (root of the physical graph).
- **Related Components:** every resource node; `TFMOD-ROOT` `DEPENDS_ON` it.
- **Files involved:** `providers.tf` (auth_url, region, endpoint_overrides).
- **Commands:** `openstack token issue`, `openstack endpoint list`.
- **Validation procedure:** `openstack server list` returns without auth/catalog errors.
- **Risks:** single-node cloud = no HA; credentials flow through tfvars (`TFVAR-OS-*`).
- **Future improvements:** `FW-VAULT` for credential injection; `FW-CICD` runners need
  endpoint reachability (see `ISSUE-LOCALHOST-ENDPOINTS`).

### `INFRA-OPENSTACK-ENDPOINTS` — Localhost Endpoint Overrides

- **Type:** Infrastructure Component · **Layer:** Networking
- **Description:** Provider `endpoint_overrides` pinning every service to `127.0.0.1`:
  identity `:5000/v3`, compute `:8774/v2.1`, network `:9696/v2.0`, image `:19292/v2`,
  volumev3 `:8776/v3`. Auth URL is likewise `http://127.0.0.1:5000/v3`.
- **Purpose:** Bypasses the service catalog so Terraform hits the local all-in-one
  services directly.
- **Dependencies:** `INFRA-OPENSTACK`.
- **Related Components:** `DEC-012`, `ISSUE-LOCALHOST-ENDPOINTS`, `DEPLOY-INIT`/`DEPLOY-PLAN`
  (fail fast when endpoints unreachable).
- **Files involved:** `providers.tf` (lines 27–36).
- **Commands:** `ss -tlnp | grep -E '5000|8774|9696|19292|8776'` (on the cloud host).
- **Validation procedure:** each port answers locally; `terraform plan` reaches all APIs.
- **Risks:** `ISSUE-LOCALHOST-ENDPOINTS`; plaintext HTTP on loopback (acceptable locally,
  fatal if endpoints are ever exposed).
- **Future improvements:** move overrides to environment/clouds.yaml for portability.

### `ISSUE-LOCALHOST-ENDPOINTS` — Terraform must run where 127.0.0.1 *is* the cloud

- **Type:** Known Issue · **Layer:** Operational + Networking
- **Description:** Because all endpoints are loopback, `terraform plan/apply` only works
  when executed **on the cloud host itself** or through a port-forward
  (e.g. `ssh -L 5000:…:5000 -L 8774:…:8774 -L 9696:…:9696 -L 19292:…:9292 -L 8776:…:8776 user@cloud-host`).
- **Impact:** blocks remote operation and any future CI runner (`FW-CICD`) unless the
  runner sits on/forwards to the host.
- **Files involved:** `providers.tf`.
- **Mitigation:** document the tunnel; parameterize endpoints per environment.
- **Related:** `DEC-012`, `INFRA-OPENSTACK-ENDPOINTS`, `FW-CICD`.

### `ISSUE-DNS` — Unresolved DNS work (branch `fix/dns-terraform`)

- **Type:** Known Issue · **Layer:** Networking
- **Description:** The working branch `fix/dns-terraform` (ahead of `main`) signals
  in-flight DNS-related changes; the code currently in the repo contains **no** DNS
  resources, so the exact scope is not yet materialized in this module.
- **Impact:** name-based access (for humans, and later for `FW-DOMAIN-DNS`/`FW-HTTPS`)
  is unavailable; all access is by literal IP (`ISSUE-HARDCODED-IPS`).
- **Files involved:** git branch `fix/dns-terraform` (no `.tf` DNS resources yet).
- **Mitigation:** track via `FW-DNS-FIX`.
- **Related:** `FW-DNS-FIX`, `FW-DOMAIN-DNS`, `NET-PRIVATE`.

---

## Graph Relationships (local view)

```
NET-PRIVATE-SUBNET  PART_OF      NET-PRIVATE
VM-BASTION          CONNECTS_TO  NET-PRIVATE
VM-LMS-OPENEDX      DEPENDS_ON   NET-PRIVATE        (and likewise VM-ODOO-SERVER,
VM-FULL-STACK-JS    DEPENDS_ON   NET-PRIVATE         VM-JAVA-JS)
VM-JAVA-JS          DEPENDS_ON   NET-PRIVATE
INFRA-FIP           PART_OF      NET-EXTERNAL
NET-EXTERNAL        CONNECTS_TO  NET-PRIVATE        (via INFRA-FIP-ASSOC path)
TFMOD-ROOT          DEPENDS_ON   INFRA-OPENSTACK
INFRA-OPENSTACK-ENDPOINTS PART_OF INFRA-OPENSTACK   (provider config)
DEC-012             RELATED_TO   INFRA-OPENSTACK-ENDPOINTS
ISSUE-LOCALHOST-ENDPOINTS RELATED_TO INFRA-OPENSTACK-ENDPOINTS
ISSUE-DNS           RELATED_TO   FW-DNS-FIX
TFDATA-PRIVATE-NETWORK  DEPENDS_ON NET-PRIVATE
TFDATA-PRIVATE-SUBNET   DEPENDS_ON NET-PRIVATE-SUBNET
TFDATA-EXTERNAL-NETWORK DEPENDS_ON NET-EXTERNAL
```

---

## Decisions (canonical text in [decisions.md](decisions.md))

- `DEC-012` — hardcoded localhost `endpoint_overrides` (simplicity for the all-in-one
  cloud; tradeoff captured in `ISSUE-LOCALHOST-ENDPOINTS`).
- `DEC-007` — no VM other than the bastion gets any address on `NET-EXTERNAL`.
- `DEC-001` — the only public address (`INFRA-FIP`) is pre-allocated outside Terraform.

---

## Terraform Knowledge

- All three networks are **data sources**, never managed resources: Terraform reads,
  never mutates (`data.tf`).
- Variable wiring: `TFVAR-PRIVATE-NETWORK-NAME` → `TFDATA-PRIVATE-NETWORK`;
  `TFVAR-PRIVATE-SUBNET-NAME` → `TFDATA-PRIVATE-SUBNET`;
  `TFVAR-EXTERNAL-NETWORK-NAME` → `TFDATA-EXTERNAL-NETWORK`.
- Provider network config lives in `providers.tf` (region `RegionOne`, auth, overrides).

---

## Infrastructure Workflow

1. Pre-flight: confirm endpoint reachability (`ISSUE-LOCALHOST-ENDPOINTS` tunnel if remote).
2. `DEPLOY-PLAN` — data sources resolve all three networks by name; a resolution
   failure here means a naming mismatch, fix tfvars, not the cloud.
3. Post-apply: `openstack port show bastion-nawel-test-port` must show a fixed IP in
   `192.168.100.0/24` and the FIP mapped (`VAL-SG-AUDIT`).

---

## Validation

- Network presence: `openstack network show reseau-stagiaires`, `openstack subnet show subnet-stagiaires`.
- Path: `VAL-SSH-BASTION` (public path) + `VAL-ICMP-PRIVATE` (private path).
- Control plane: `openstack token issue` against `http://127.0.0.1:5000/v3`.

---

## Operational Procedures

- **Bring up remote access to the control plane** (needed before any Terraform run
  from a laptop): open the SSH multi-port forward described in
  `ISSUE-LOCALHOST-ENDPOINTS`, keep it alive for the duration of `plan`/`apply`.
- **Diagnose FIP path**: `openstack floating ip show <ip>` → verify `port_id` →
  `openstack port show <port_id>` → verify device owner = bastion server ID.
- Full runbook: [operations.md](operations.md).

---

## Future Roadmap

- `FW-DNS-FIX` → `FW-DOMAIN-DNS` → `FW-HTTPS` chain terminates the IP-literal era.
- CIDR parameterization (remove literal `192.168.100.0/24` from `security-groups.tf`).
- Possible network segmentation if MERN trio lands (`FW-MERN-ONBOARDING`).

---

## AI Retrieval Optimization

- **Keywords:** reseau-stagiaires, subnet-stagiaires, 192.168.100.0/24, public network, floating IP pool, neutron, endpoint_overrides, 127.0.0.1, RegionOne, DevStack, all-in-one OpenStack, port-forward, DNS fix branch
- **Tags:** #networking #neutron #subnet #floating-ip #endpoints #control-plane
- **Related Nodes:** `SG-BASTION`, `SG-PRIVATE-VMS`, `INFRA-BASTION-PORT`, `INFRA-FIP`, `TFMOD-ROOT`
- **Parent Nodes:** `INFRA-OPENSTACK`
- **Child Nodes:** `NET-PRIVATE`, `NET-PRIVATE-SUBNET`, `NET-EXTERNAL`, `INFRA-OPENSTACK-ENDPOINTS`
- **Cross References:** [bastion-host.md](bastion-host.md), [security-model.md](security-model.md), [terraform-platform.md](terraform-platform.md), [future-roadmap.md](future-roadmap.md)
- **Aliases:** réseau privé des stagiaires (fr), tenant network, provider network, control plane endpoints
- **Infrastructure Layer:** `INFRA-OPENSTACK`
- **Networking Layer:** `NET-*`, `INFRA-OPENSTACK-ENDPOINTS`
- **Security Layer:** boundaries A–D (see Architecture)
- **Terraform Layer:** `data.tf`, `providers.tf`
- **Operational Layer:** `ISSUE-LOCALHOST-ENDPOINTS`, `ISSUE-DNS`, port-forward procedure
