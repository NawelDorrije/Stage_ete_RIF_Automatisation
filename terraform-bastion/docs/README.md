# Infrastructure Knowledge Base — terraform-bastion

This directory is the **canonical long-term memory** of the `terraform-bastion` project.
It is a **knowledge graph rendered as Markdown**, designed for AI agents, RAG/GraphRAG
retrieval, dependency analysis, troubleshooting, and onboarding — not for linear reading.

Source of truth for *definitions* = the feature document where a node is fully defined.
Source of truth for *topology* = [`graph/INDEX.md`](graph/INDEX.md) and [`graph/graph.json`](graph/graph.json).

---

## Graph Conventions

### Node Types

| Prefix | Type | Examples |
|---|---|---|
| `INFRA-` | Infrastructure Component | cloud platform, floating IP, keypair, cloud-init, Ansible |
| `VM-` | Virtual Machine | bastion, LMS-OpenedX, Odoo |
| `NET-` | Network / Subnet | private network, external network |
| `SG-` | Security Group / Rule / Association | sg-bastion, SSH rules |
| `TFMOD-` | Terraform Module | root module |
| `TFVAR-` | Terraform Variable | `allowed_admin_cidrs` |
| `TFOUT-` | Terraform Output | `ssh_bastion` |
| `TFDATA-` | Terraform Data Source | private network lookup |
| `DEPLOY-` | Deployment Step | init, plan, apply |
| `DEC-` | Architectural Decision | reuse existing Floating IP |
| `PRIN-` | Design Principle | single controlled entry point |
| `OP-` | Operational Procedure | add a VM, retrieve a Port ID |
| `ISSUE-` | Known Issue | hardcoded IPs in outputs |
| `VAL-` | Validation | terraform validate, SSH checks |
| `SSH-` | SSH Workflow | ProxyJump workflow |
| `RP-` | Reverse Proxy | future NGINX/Traefik node |
| `FW-` | Future Work | HTTPS, DNS, monitoring |
| `ACTOR-` | Human/System Actor | administrators |

### Relationship Vocabulary (edge predicates)

`DEPENDS_ON` · `USES` · `EXPOSES` · `CONNECTS_TO` · `PROTECTS` · `GENERATES` ·
`CONFIGURES` · `VALIDATES` · `IMPLEMENTS` · `REPLACES` · `IS_ACCESSED_VIA` ·
`PART_OF` · `RELATED_TO` · `SUPERSEDES`

### Layers

Every node belongs to one or more layers, used as retrieval filters:

- **Infrastructure Layer** — physical/logical resources in OpenStack
- **Networking Layer** — networks, subnets, ports, floating IPs
- **Security Layer** — security groups, hardening, key material
- **Terraform Layer** — module, variables, outputs, state, lifecycle
- **Operational Layer** — procedures, validations, workflows, roadmap

### Node Card Schema

Every canonical node definition contains:

`ID` · `Name` · `Type` · `Layer` · `Description` · `Purpose` · `Dependencies` ·
`Related Components` · `Files involved` · `Commands` · `Validation procedure` ·
`Risks` · `Future improvements`

### Rules of this Knowledge Base

1. **No duplication.** Each node is *fully defined* in exactly one feature document
   (its **home document**). Other documents reference it by ID only.
2. **Explicit relationships.** Facts are expressed as `SUBJECT —PREDICATE→ OBJECT`
   triples. The master edge list lives in `graph/INDEX.md`; a machine-readable
   export lives in `graph/graph.json`.
3. **Evidence.** Every node card lists the files that prove its existence.
4. **Cross-references.** `→ See: <doc>` always points to the home document of a node.

---

## File Map

| File | Contents |
|---|---|
| [`graph/INDEX.md`](graph/INDEX.md) | Master node registry + master edge table |
| [`graph/bastion-host.md`](graph/bastion-host.md) | Bastion VM, port, Floating IP, cloud-init, Ansible hardening |
| [`graph/networking.md`](graph/networking.md) | Private/external networks, subnet, endpoints, traffic flow |
| [`graph/security-model.md`](graph/security-model.md) | Security groups, rules, trust boundaries, CIDR policy |
| [`graph/ssh-workflows.md`](graph/ssh-workflows.md) | Direct SSH, ProxyJump, key management, client config |
| [`graph/vm-integration.md`](graph/vm-integration.md) | Existing VMs, pilot rollout, port association |
| [`graph/terraform-platform.md`](graph/terraform-platform.md) | Module, provider, backend, variables, outputs, execution order |
| [`graph/operations.md`](graph/operations.md) | Runbook: all operational procedures + validation ladder |
| [`graph/decisions.md`](graph/decisions.md) | All architectural decisions + design principles |
| [`graph/future-roadmap.md`](graph/future-roadmap.md) | Future work as graph nodes (proxy, HTTPS, DNS, monitoring…) |
| [`graph/graph.json`](graph/graph.json) | Machine-readable nodes + edges export |

---

## How an AI Agent Should Use This Graph

1. **Locate a node**: search `graph/INDEX.md` registry by name, alias, or keyword.
2. **Read its canonical card**: jump to the home document listed in the registry.
3. **Traverse**: follow edge IDs in the master edge table to expand context
   (dependencies, dependents, protections, validations).
4. **Reason about impact**: to assess a change, collect all edges where the node is
   the *object* of `DEPENDS_ON`, `CONFIGURES`, `PROTECTS`, `VALIDATES`.
5. **Answer operational questions**: start from `OP-*` nodes in `operations.md`.
6. **Answer "why" questions**: start from `DEC-*` and `PRIN-*` nodes in `decisions.md`.

### Example queries this graph answers

- *"What breaks if I change `allowed_admin_cidrs`?"* → edges of `TFVAR-ALLOWED-ADMIN-CIDRs`
- *"How do I connect to Odoo?"* → `TFOUT-SSH-ODOO-SERVER` → `SSH-PROXYJUMP` → `VM-ODOO-SERVER`
- *"Why doesn't Terraform create the Floating IP?"* → `DEC-001`
- *"Why didn't my new SSH key appear on the bastion?"* → `ISSUE-USERDATA-DRIFT` + `OP-ADD-SSH-KEY`
- *"What is the rollout order for securing VMs?"* → `DEC-005` → `SG-ASSOC-PILOT-VMS`

---

## AI Retrieval Optimization

- **Keywords:** knowledge graph, GraphRAG, RAG, infrastructure documentation, node registry, edge table, canonical knowledge base, terraform-bastion, OpenStack
- **Tags:** #knowledge-base #conventions #navigation #graph-schema
- **Related Nodes:** all (this is the schema document)
- **Parent Nodes:** none (root document)
- **Child Nodes:** `graph/INDEX.md`, all feature documents
- **Cross References:** project root `README.md`
- **Aliases:** KB home, graph conventions, documentation schema
- **Layers:** Operational Layer (meta)
