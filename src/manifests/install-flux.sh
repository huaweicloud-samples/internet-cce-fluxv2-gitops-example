#!/usr/bin/env bash
#
# 在已就绪的 CCE 集群上安装 Flux v2 并应用 GitOps 引导清单。
# 等价于原 AWS CDK 中 fluxv2.ts 通过 addManifest 引导 Flux 的过程，
# 区别仅在于此处用 kubectl 清单交付（符合华为云 CCE 工作负载拆分约束）。
#
set -euo pipefail

# 可覆盖：FLUX_VERSION 默认锁定一个稳定版本
FLUX_VERSION="${FLUX_VERSION:-v2.4.0}"

if [ -z "${KUBECONFIG:-}" ] && [ ! -f "${HOME}/.kube/config" ]; then
  echo "错误：未找到 kubeconfig。请先通过 'hcloud cce kubeconfig get' 获取指向目标 CCE 集群的凭据。"
  exit 1
fi

echo ">> [1/3] 安装 Flux 组件（${FLUX_VERSION}）"
kubectl apply -f "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/install.yaml"

echo ">> [2/3] 等待 flux-system 控制器就绪"
kubectl -n flux-system rollout status deploy/source-controller --timeout=300s
kubectl -n flux-system rollout status deploy/kustomize-controller --timeout=300s

echo ">> [3/3] 应用 GitOps 引导清单（GitRepository + Kustomization）"
kubectl apply -f "$(dirname "$0")/flux-bootstrap.yaml"

echo ">> 完成。Flux 将开始按 interval 同步 k8s-config/clusters/demo 声明的集群状态。"
echo "   手动触发调和：flux reconcile kustomization flux-system --with-source"
