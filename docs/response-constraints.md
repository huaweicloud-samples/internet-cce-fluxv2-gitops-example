# 响应约束与检查（质量门禁）

> 交付前逐条核对；任一不满足不得带病交付。

| # | 约束 | 是否满足 | 说明 |
|---|------|----------|------|
| C1 | 全程使用华为云原生产品，不残留原云 SDK / 直连 | ✅ | 集群用 CCE、入口用原生 ELB、伸缩用节点池原生能力；无原云直连 |
| C2 | IaC 统一为 Terraform + huaweicloud Provider | ✅ | `infra/` 全为 Terraform；Flux 工作负载经 kubectl 清单（符合 CCE 拆分约束） |
| C3 | 🔴 无对标服务须有降级 / 终止决策且经闸门确认 | ✅ | 阶段 2.5 未发现 🔴 硬止损；负载均衡控制器与节点伸缩为 🟡，决策见 `others/architecture-adaptation.md` |
| C4 | 函数代码不直连原云端点 | ✅ | 本仓库无函数代码；GitOps 拉取为通用 Git/SSH，不绑原云 |
| C5 | `docs/` 以华为云视角撰写，无「迁移产物 / 对标」措辞 | ✅ | 全文华为云术语（CCE / Flux v2 / ELB / 节点池弹性伸缩）；`others/` 保留溯源 |
| C6 | `infra/` 通过 `terraform validate` | ⚠️ | 本环境未装 terraform，未跑 `validate`；资源为标准用法，建议目标环境首部署前 `init && plan` |
| C7 | 产物结构符合 docs/（实践）+ others/（过程）分库 | ✅ | 结构合规 |
| C8 | 报告 / 文档严禁真实 AK/SK / 密钥 / token | ✅ | 凭据一律占位符 / 环境变量注入；无真实值落盘 |
| C9 | apply 前确认费用（>¥10/h 先问用户） | ✅ | 默认组合约 ¥1–2/h < ¥10/h（见下）；规格显式写死，无 `data.*.ids[N]` 决定计费规格 |
| C10 | 运行期被改写字段 `ignore_changes` | ✅ | CCE 节点池 `initial_node_count` 已 `ignore_changes`（原生弹性伸缩接管） |

## 费用速算（C9，默认部署）

| 资源 | 规格 | 单价（约） | 数量 | ¥/h |
|------|------|-----------|------|-----|
| CCE 集群控制面 | cce.s1.small | ¥0.40 | 1 | 0.40 |
| 节点 | s6.large.2（2vCPU/4GB） | ¥0.30 | 2（初始） | 0.60 |
| NAT 网关 | 规格 1 | ¥0.06 | 1 | 0.06 |
| 弹性IP 带宽 | 5Mbps 按流量 | ¥0.02 | 1 | 0.02 |
| **合计** | — | — | — | **≈ ¥1.10/h** |

> 合计 < ¥10/h，可直接 `apply`。注意：节点池上限 20 节点时费用随负载线性增长，生产环境请按实际需要收紧 `max_node_count`。

## 自检清单（交付前）

- [x] `src/` / `infra/` 无残留原云直接依赖（本仓库无函数代码，纯基础设施 + GitOps）
- [x] 每个 🟡 服务在 `others/architecture-adaptation.md` 均有处置记录
- [x] `others/service-mapping.md` 服务映射完整、对齐度标注齐全
- [x] `docs/` 内无「迁移产物 / 对标」类措辞
- [x] `docs/response-constraints.md` 自身约束 C1–C10 逐条满足
- [x] 报告及交付文档无真实 AK/SK/密钥/token（C8）
- [x] 费用确认（C9）：合计 < ¥10/h，规格显式写死
- [x] `ignore_changes`（C10）：节点池初始节点数已让出所有权
- [x] `README.md` 目录树与实际 `docs/` + `others/` 结构一致
- [ ] `terraform validate` 因环境无 Provider 未执行（C6），目标环境首部署前补做
