# 架构说明 · CCE + Flux v2 GitOps 示例

> 本文档从华为云视角描述本最佳实践，不保留原云迁移措辞。

## 一、总体架构

本实践用 **CCE 云容器引擎** 一键拉起一个托管 Kubernetes 集群，并通过 **Flux v2（GitOps 工具链）** 把集群状态与 Git 仓库持续对齐。集群启动后，Flux 监听 `k8s-config/` 目录，自动调和命名空间、度量服务、示例应用等资源。

```
                         Git 仓库（存放 k8s-config/）
                                  │  SSH（keypair 认证）
                                  ▼
        ┌─────────────────────────────────────────────┐
        │  CCE 集群（VirtualMachine）                    │
        │   ├─ Flux v2 组件（source / kustomize 控制器） │
        │   ├─ nginx-ingress 插件（置备公网 ELB）        │
        │   ├─ metrics-server（远程 base）               │
        │   └─ podinfo 示例应用（HelmRelease）           │
        └─────────────────────────────────────────────┘
                                  │
        ┌─────────────────────────────────────────────┐
        │  网络：VPC + 公私网子网 + NAT + 弹性IP + 安全组 │
        │  权限：IAM 委托（CCE 访问 VPC / ELB）          │
        └─────────────────────────────────────────────┘
```

## 二、核心组件

| 组件 | 作用 |
|------|------|
| CCE 集群 | 托管 Kubernetes 控制面 + 节点池（弹性伸缩 1–20 节点） |
| Flux v2 | GitOps：把 Git 仓库声明的状态持续调和到集群 |
| nginx-ingress 插件 | 为 Ingress 自动置备公网 ELB（等价于原负载均衡入口控制器） |
| metrics-server | 集群度量（HPA 依赖），取自社区远程 base |
| podinfo | 演示应用（Helm 部署，2 副本，ingress 暴露） |

## 三、目录与仓库关系

- `infra/`：Terraform，产出 CCE 集群、节点池、网络、IAM 委托。
- `src/manifests/`：Flux 安装脚本与 GitOps 引导清单（集群就绪后 apply）。
- `k8s-config/`：Flux 监听的 GitOps 内容（集群状态声明），与基础设施解耦，可独立迭代。
