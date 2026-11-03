# 部署指导书 · CCE + Flux v2 GitOps 示例

> 全流程使用华为云原生产品；凭据仅经环境变量 / Secret 注入，不落盘。

## 一、前置条件

- 已安装：`terraform`（≥1.70）、`kubectl`、`hcloud`（华为云 CLI）、`flux`（可选，用于手动触发调和）。
- 已配置华为云凭据（AK/SK 注入环境变量 `HW_ACCESS_KEY` / `HW_SECRET_KEY`）。
- 一个 Git 仓库，用于存放 `k8s-config/`（本实践已包含示例内容，推到你的仓库即可）。

## 二、步骤 1：部署基础设施（Terraform）

```bash
cd infra/
terraform init
terraform plan                 # 只读探测，确认规格/区域/端点可用
terraform apply -auto-approve  # 创建 VPC / 子网 / NAT / CCE 集群 + 节点池 / IAM 委托
```

完成后记录输出：`cce_cluster_name`、`cce_cluster_id`、`get_kubeconfig_hint`。

## 三、步骤 2：获取 kubeconfig

```bash
hcloud cce kubeconfig get --cluster-name <cce_cluster_name> --region cn-north-4 > ~/.kube/config
kubectl get nodes              # 确认节点就绪（初始 2 个，按负载弹性伸缩 1–20）
```

## 四、步骤 3：准备 Git 凭据（SSH keypair）

Flux 以 SSH 方式拉取 Git 仓库，与原实现一致（便于切换代码托管平台）。

```bash
# 1) 生成 keypair
ssh-keygen -C demokey -N "" -f $HOME/.ssh/demo_key_rsa
# 2) 把公钥（.pub）添加到你的 Git 仓库部署密钥（只读）
# 3) 在集群创建包含私钥的 Secret（flux-system 命名空间）
kubectl -n flux-system create secret generic github-keypair \
  --from-file=identity=$HOME/.ssh/demo_key_rsa \
  --from-file=identity.pub=$HOME/.ssh/demo_key_rsa.pub \
  --from-file=known_hosts=<(ssh-keyscan github.com)
```

> 若使用华为云代码托管，流程相同，仅把 `github.com` 替换为对应域名与公钥上传位置。

## 五、步骤 4：安装 Flux v2 并引导

```bash
cd src/manifests/
# 先编辑 flux-bootstrap.yaml 中的 url，指向你存放 k8s-config/ 的仓库
bash install-flux.sh
```

脚本会：① 拉取 Flux 官方 `install.yaml` 并 apply；② 等待控制器就绪；③ apply `flux-bootstrap.yaml`（GitRepository + Kustomization）。

## 六、步骤 5：验证 GitOps 调和

```bash
kubectl -n podinfo get pods        # 等待 podinfo-*-* Running（2 副本）
kubectl -n podinfo get ingress     # 确认 ingress 由 nginx-ingress 插件置备公网 ELB
flux get kustomizations --all-namespaces
```

手动触发调和：`flux reconcile kustomization flux-system --with-source`。

## 七、清理

```bash
kubectl -n flux-system delete -f src/manifests/flux-bootstrap.yaml   # 停止调和
cd infra/ && terraform destroy -auto-approve                          # 回收云资源
```

> 计费资源（CCE 集群、节点、NAT、弹性IP）删除即停费；建议调试完毕及时 `destroy` 并核对云端无残留。
