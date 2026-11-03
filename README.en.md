# CCE + Flux v2 GitOps Example (cce-fluxv2-gitops-example)

> A minimal, runnable best practice that uses **CCE Cloud Container Engine** + **Flux v2 (GitOps)** to spin up a managed Kubernetes cluster in one go and keep the cluster state continuously reconciled with a Git repository.

![License](https://img.shields.io/badge/license-MIT--0-blue)
![Cloud](https://img.shields.io/badge/cloud-HuaweiCloud-orange)
![Build](https://img.shields.io/badge/IaC-Terraform--huaweicloud-success)

---

## Table of Contents

- [1. Title & Badges](#1-title-badges)
- [2. Project Overview](#2-project-overview)
- [3. Directory Structure](#3-directory-structure)
- [4. Architecture Diagram](#4-architecture-diagram)
- [5. Key Highlights](#5-key-highlights)
- [6. Cloud Services & Cost](#6-cloud-services-cost)
- [7. Prerequisites](#7-prerequisites)
- [8. Quick Start](#8-quick-start)
- [9. Step-by-Step Deployment](#9-step-by-step-deployment)
- [10. Usage & Verification](#10-usage-verification)
- [11. Cleanup](#11-cleanup)
- [12. Detailed Documentation](#12-detailed-documentation)
- [13. Dependencies & Acknowledgements](#13-dependencies-acknowledgements)
- [14. FAQ](#14-faq)
- [15. Contributing](#15-contributing)
- [16. License](#16-license)
- [17. Submitter*](#17-Submitter*)

---

## 1. Title & Badges

This repository is a production-ready **CCE + Flux v2 GitOps** best practice on Huawei Cloud, equivalent to a "managed Kubernetes + GitOps bootstrap" sample.

## 2. Project Overview

Terraform provisions the CCE cluster, node pools (native auto-scaling), networking, and IAM delegation. Once the cluster is ready, Flux v2 continuously reconciles the cluster state declared in `k8s-config/` against production. Infrastructure and GitOps content are decoupled and can be iterated independently.

## 3. Directory Structure

```
cce-fluxv2-gitops-example/
├── README.md
├── docs/                         # Huawei Cloud practice docs
│   ├── architecture.md           # Architecture overview
│   ├── deployment-guide.md       # Deployment guide
│   └── response-constraints.md   # Quality gates
├── others/                       # Process artifacts (traceability / audit)
│   ├── analysis.txt
│   ├── service-mapping.md
│   ├── architecture-adaptation.md
│   └── migration-report.md
├── infra/                        # Terraform (CCE + networking + IAM delegation)
│   ├── versions.tf
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
├── src/manifests/                # Flux installation & GitOps bootstrap (kubectl delivery)
│   ├── install-flux.sh
│   └── flux-bootstrap.yaml
└── k8s-config/                   # GitOps content watched by Flux
    ├── clusters/demo/
    ├── addons/metrics-server/
    └── apps/podinfo/base/
```

## 4. Architecture Diagram

```
                         Git repository (k8s-config/)
                                  │ SSH keypair
                                  ▼
        ┌──────────────────────────────────────────┐
        │ CCE Cluster                                │
        │  ├─ Flux v2 (source / kustomize controllers)│
        │  ├─ nginx-ingress add-on (provisions public ELB)│
        │  ├─ metrics-server                         │
        │  └─ podinfo sample app                     │
        └──────────────────────────────────────────┘
                  │
        ┌──────────────────────────────────────────┐
        │ VPC + private/public subnets + NAT + EIP + security groups │
        │ IAM delegation (CCE accesses VPC / ELB)   │
        └──────────────────────────────────────────┘
```

## 5. Key Highlights

- **GitOps out of the box**: The cluster is continuously reconciled by Flux against the Git-declared state as soon as it starts.
- **Native auto-scaling**: `scaling_enabled` on the node pool is directly equivalent to node group auto-scaling, with no extra credentials required.
- **Zero-ops ingress**: Ingress/Service automatically provisions a public ELB via annotations, with no separate load balancer controller to run.
- **Pure IaC, fully reproducible**: Infrastructure is managed with Terraform, and GitOps content is versioned.

## 6. Cloud Services & Cost

| Service | Spec | ~¥/h |
|---------|------|------|
| CCE cluster | cce.s1.small | 0.40 |
| Node | s6.large.2 × 2 | 0.60 |
| NAT Gateway | Spec 1 | 0.06 |
| Elastic IP | 5 Mbps, traffic-based | 0.02 |
| **Total** | — | **≈ 1.10** |

The total stays under ¥10/h and can be deployed as-is; nodes scale elastically with load, so tighten the cap as needed in production.

## 7. Prerequisites

- `terraform` ≥ 1.70, `kubectl`, and `hcloud` (Huawei Cloud CLI).
- Huawei Cloud credentials (inject AK/SK via `HW_ACCESS_KEY` / `HW_SECRET_KEY`).
- A Git repository to host `k8s-config/`.

## 8. Quick Start

```bash
# 1) Infrastructure
cd infra/ && terraform init && terraform apply -auto-approve

# 2) Fetch kubeconfig
hcloud cce kubeconfig get --cluster-name <cce_cluster_name> --region cn-north-4 > ~/.kube/config

# 3) Prepare Git SSH credentials (see the deployment guide)
kubectl -n flux-system create secret generic github-keypair --from-file=identity=$HOME/.ssh/demo_key_rsa ...

# 4) Install Flux and bootstrap
cd src/manifests/ && bash install-flux.sh
```

## 9. Step-by-Step Deployment

See `docs/deployment-guide.md`: ① Terraform provisions infrastructure → ② fetch kubeconfig → ③ create the Git SSH secret → ④ `install-flux.sh` bootstraps Flux → ⑤ verify podinfo reconciliation and the ingress ELB.

## 10. Usage & Verification

```bash
kubectl -n podinfo get pods        # 2 replicas Running
kubectl -n podinfo get ingress     # nginx-ingress has provisioned a public ELB
flux get kustomizations --all-namespaces
```

Modify `k8s-config/` and push; Flux reconciles automatically within `interval` (10m). You can also trigger it manually with `flux reconcile kustomization flux-system --with-source`.

## 11. Cleanup

```bash
kubectl -n flux-system delete -f src/manifests/flux-bootstrap.yaml
cd infra/ && terraform destroy -auto-approve
```

## 12. Detailed Documentation

`docs/architecture.md` describes the component-to-capability mapping; `docs/deployment-guide.md` provides step-by-step operations; `docs/response-constraints.md` records the quality gates.

## 13. Dependencies & Acknowledgements

- Flux v2 (CNCF GitOps Toolkit, open source).
- podinfo demo application (stefanprodan/podinfo Helm repository).
- metrics-server (kubernetes-sigs remote base).

## 14. FAQ

**Q: Why nginx-ingress instead of a standalone load balancer controller?**
A: CCE natively integrates ELB; the nginx-ingress add-on automatically provisions a public ELB, which is equivalent to the original load-balancer ingress capability and requires no operations effort.

**Q: How does node scaling work?**
A: With `scaling_enabled` enabled on the node pool, the CCE control plane scales between 1–20 nodes based on load, without requiring cloud API credentials.

**Q: Can I switch to a different Git host?**
A: Yes. Flux pulls over SSH; just upload the public key to the platform of your choice. It is decoupled from any specific code-hosting provider.

## 15. Contributing

Issues and pull requests are welcome. Please keep the native Huawei Cloud product perspective and avoid introducing dependencies specific to other cloud vendors.

## 16. License

This practice is licensed under the MIT-0 license. See `LICENSE`.

## 17. Submitter*

**Submitter**: zhangcheng123321