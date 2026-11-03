# CCE + Flux v2 GitOps 示例（cce-fluxv2-gitops-example）

> 用 **CCE 云容器引擎** + **Flux v2（GitOps）** 一键拉起托管 Kubernetes 集群，并把集群状态与 Git 仓库持续对齐的最小可运行最佳实践。

![License](https://img.shields.io/badge/license-MIT--0-blue)
![Cloud](https://img.shields.io/badge/cloud-HuaweiCloud-orange)
![Build](https://img.shields.io/badge/IaC-Terraform--huaweicloud-success)

---

## 目录导航

- [1. 标题与徽章](#1-标题与徽章)
- [2. 项目简介](#2-项目简介)
- [3. 目录](#3-目录)
- [4. 架构图](#4-架构图)
- [5. 方案亮点](#5-方案亮点)
- [6. 涉及云服务](#6-涉及云服务)
- [7. 前置条件](#7-前置条件)
- [8. 快速开始](#8-快速开始)
- [9. 分步部署](#9-分步部署)
- [10. 使用方法与验证](#10-使用方法与验证)
- [11. 清理资源](#11-清理资源)
- [12. 详细说明](#12-详细说明)
- [13. 依赖与致谢](#13-依赖与致谢)
- [14. 常见问题（FAQ）](#14-常见问题（faq）)
- [15. 贡献指南](#15-贡献指南)
- [16. 许可证](#16-许可证)
- [17. 提交者](#17-提交者)

---

## 1. 标题与徽章

本仓库为华为云可落地的 **CCE + Flux v2 GitOps** 最佳实践，等价于一份「托管 Kubernetes + GitOps 引导」样例。

## 2. 项目简介

通过 Terraform 产出 CCE 集群、节点池（原生弹性伸缩）、网络与权限委托；集群就绪后，用 Flux v2 把 `k8s-config/` 中声明的集群状态持续调和到线上。基础设施与 GitOps 内容解耦，可独立迭代。

## 3. 目录

```
cce-fluxv2-gitops-example/
├── README.md
├── docs/                         # 华为云实践文档
│   ├── architecture.md           # 架构说明
│   ├── deployment-guide.md       # 部署指导书
│   └── response-constraints.md   # 质量门禁
├── others/                       # 过程产物（溯源 / 审计）
│   ├── analysis.txt
│   ├── service-mapping.md
│   ├── architecture-adaptation.md
│   └── migration-report.md
├── infra/                        # Terraform（CCE + 网络 + IAM 委托）
│   ├── versions.tf
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
├── src/manifests/                # Flux 安装与 GitOps 引导（kubectl 交付）
│   ├── install-flux.sh
│   └── flux-bootstrap.yaml
└── k8s-config/                   # Flux 监听的 GitOps 内容
    ├── clusters/demo/
    ├── addons/metrics-server/
    └── apps/podinfo/base/
```

## 4. 架构图

```
                         Git 仓库（k8s-config/）
                                  │ SSH keypair
                                  ▼
        ┌──────────────────────────────────────────┐
        │ CCE 集群                                    │
        │  ├─ Flux v2（source / kustomize 控制器）    │
        │  ├─ nginx-ingress 插件（置备公网 ELB）      │
        │  ├─ metrics-server                         │
        │  └─ podinfo 示例应用                        │
        └──────────────────────────────────────────┘
                  │
        ┌──────────────────────────────────────────┐
        │ VPC + 公私网子网 + NAT + 弹性IP + 安全组    │
        │ IAM 委托（CCE 访问 VPC / ELB）             │
        └──────────────────────────────────────────┘
```

## 5. 方案亮点

- **GitOps 开箱即用**：集群启动即由 Flux 持续调和 Git 声明状态。
- **原生弹性伸缩**：节点池 `scaling_enabled` 直接等价于节点组自动伸缩，无需额外凭据。
- **入口零运维**：Ingress / Service 经注解自动置备 ELB，无需独立负载均衡控制器。
- **纯 IaC 可复现**：基础设施 Terraform 管理，GitOps 内容版本化。

## 6. 涉及云服务

| 服务 | 规格 |
|------|------|
| CCE 集群 | cce.s1.small |
| 节点 | s6.large.2 × 2 |
| NAT 网关 | 规格 1 |
| 弹性IP | 5Mbps 按流量 |
| **合计** | — |

## 7. 前置条件

- `terraform` ≥ 1.70、`kubectl`、`hcloud`（华为云 CLI）。
- 华为云凭据（AK/SK 注入 `HW_ACCESS_KEY` / `HW_SECRET_KEY`）。
- 一个用于存放 `k8s-config/` 的 Git 仓库。

## 8. 快速开始

```bash
# 1) 基础设施
cd infra/ && terraform init && terraform apply -auto-approve

# 2) 获取 kubeconfig
hcloud cce kubeconfig get --cluster-name <cce_cluster_name> --region cn-north-4 > ~/.kube/config

# 3) 准备 Git SSH 凭据（见部署指导书）
kubectl -n flux-system create secret generic github-keypair --from-file=identity=$HOME/.ssh/demo_key_rsa ...

# 4) 安装 Flux 并引导
cd src/manifests/ && bash install-flux.sh
```

## 9. 分步部署

详见 `docs/deployment-guide.md`：① Terraform 建基础设施 → ② 取 kubeconfig → ③ 建 Git SSH Secret → ④ `install-flux.sh` 引导 Flux → ⑤ 验证 podinfo 调和与 ingress ELB。

## 10. 使用方法与验证

```bash
kubectl -n podinfo get pods        # 2 副本 Running
kubectl -n podinfo get ingress     # nginx-ingress 已置备公网 ELB
flux get kustomizations --all-namespaces
```

修改 `k8s-config/` 并推送，Flux 会在 `interval`（10m）内自动调和；也可 `flux reconcile kustomization flux-system --with-source` 手动触发。

## 11. 清理资源

```bash
kubectl -n flux-system delete -f src/manifests/flux-bootstrap.yaml
cd infra/ && terraform destroy -auto-approve
```

## 12. 详细说明

`docs/architecture.md` 描述组件与能力对应；`docs/deployment-guide.md` 提供逐步操作；`docs/response-constraints.md` 记录质量门禁。

## 13. 依赖与致谢

- Flux v2（CNCF GitOps Toolkit，开源）。
- podinfo 演示应用（stefanprodan/podinfo Helm 仓库）。
- metrics-server（kubernetes-sigs 远程 base）。

## 14. 常见问题（FAQ）

**Q：入口为什么用 nginx-ingress 而不是独立负载均衡控制器？**
A：CCE 原生集成 ELB，nginx-ingress 插件即自动置备公网 ELB，等价于原负载均衡入口能力，且免运维。

**Q：节点伸缩如何工作？**
A：节点池开启 `scaling_enabled`，由 CCE 控制面按负载在 1–20 间伸缩，无需云 API 凭据。

**Q：可以换 Git 托管吗？**
A：可以。Flux 以 SSH 方式拉取，公钥上传到对应平台即可，与具体代码托管解耦。

## 15. 贡献指南

欢迎提交 Issue / PR 改进本实践。请保持 Huawei Cloud 原生产品视角，避免引入其他云厂商专属依赖。

## 16. 许可证

本实践基于 MIT-0 许可证，详见 `LICENSE`。

## 17. 提交者

- 提交者：zhangcheng123321