# terraform-bastion

Hardened SSH bastion on OpenStack: a single public entry point
(`bastion-nawel-test`) into the private network `reseau-stagiaires`
(`192.168.100.0/24`), protecting the training VMs (LMS-OpenedX, Odoo,
Full-Stack-JS, Java-JS) behind bastion-only security groups.

- Terraform ≥ 1.7 · provider `openstack ~> 1.53.0` · state in Terraform Cloud
  (`rif-stagiaires` / `Nawel-Bastion-Test`)
- Quick access: `terraform output` prints ready-to-use `ssh` / `ssh -J` commands.

## Documentation — Infrastructure Knowledge Graph

This project is documented as a **knowledge graph** (nodes + typed relationships),
optimized for AI retrieval (RAG/GraphRAG), dependency analysis, and onboarding.
Start here:

- **[docs/README.md](docs/README.md)** — graph conventions (node IDs, predicates, layers)
- **[docs/graph/INDEX.md](docs/graph/INDEX.md)** — master node registry + edge table
- **[docs/graph/graph.json](docs/graph/graph.json)** — machine-readable export

Feature documents:

| Topic | File |
|---|---|
| Bastion host (VM, port, FIP, cloud-init, Ansible) | [docs/graph/bastion-host.md](docs/graph/bastion-host.md) |
| Networking (networks, subnet, endpoints) | [docs/graph/networking.md](docs/graph/networking.md) |
| Security model (security groups, trust boundaries) | [docs/graph/security-model.md](docs/graph/security-model.md) |
| SSH workflows (ProxyJump, keys) | [docs/graph/ssh-workflows.md](docs/graph/ssh-workflows.md) |
| Existing VM integration (pilot rollout) | [docs/graph/vm-integration.md](docs/graph/vm-integration.md) |
| Terraform platform (module, variables, outputs) | [docs/graph/terraform-platform.md](docs/graph/terraform-platform.md) |
| Operations runbook (procedures, validation) | [docs/graph/operations.md](docs/graph/operations.md) |
| Decisions & principles (ADR) | [docs/graph/decisions.md](docs/graph/decisions.md) |
| Future roadmap (proxy, HTTPS, DNS, monitoring…) | [docs/graph/future-roadmap.md](docs/graph/future-roadmap.md) |

## TL;DR usage

```bash
terraform init && terraform plan && terraform apply
terraform output ssh_bastion          # ssh ubuntu@<floating-ip>
terraform output ssh_lms_openedx      # ssh -J ubuntu@<floating-ip> ubuntu@192.168.100.55
```

Rules of the house: never give a VM a Floating IP (`DEC-007`); never rely on
`user_data` changes after first boot (`ISSUE-USERDATA-DRIFT` — use Ansible);
always keep `allowed_admin_cidrs` at `/32`.
