# ============================================================================
# EKS + Flux v2 GitOps 示例 · 华为云等价复刻（CCE + Flux v2）
# 管理：VPC / 子网 / 安全组 / NAT / CCE 集群 + 节点池（原生弹性伸缩）/ IAM 委托
# 说明：Flux v2 组件与 GitOps 工作负载经 kubectl 清单交付（见 src/manifests），
#       不在此 Terraform 内声明（符合 CCE 工作负载拆分约束）。
# ============================================================================

locals {
  tags = {
    Blueprint  = "cce-fluxv2-gitops-example"
    ManagedBy  = "terraform"
    Project    = var.project_name
  }
}

# ---------------------------------------------------------------------------
# 网络
# ---------------------------------------------------------------------------
resource "huaweicloud_vpc" "this" {
  name = var.project_name
  cidr = var.vpc_cidr
  tags = local.tags
}

resource "huaweicloud_vpc_subnet" "public" {
  count      = length(var.public_subnet_cidrs)
  name       = "${var.project_name}-public-${count.index}"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = var.public_subnet_cidrs[count.index]
  gateway_ip = cidrhost(var.public_subnet_cidrs[count.index], 1)
  tags       = local.tags
}

resource "huaweicloud_vpc_subnet" "private" {
  count      = length(var.private_subnet_cidrs)
  name       = "${var.project_name}-private-${count.index}"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = var.private_subnet_cidrs[count.index]
  gateway_ip = cidrhost(var.private_subnet_cidrs[count.index], 1)
  tags       = local.tags
}

resource "huaweicloud_vpc_eip" "nat" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "${var.project_name}-nat-bandwidth"
    size        = 5
    share_type  = "PER"
    charge_mode = "traffic"
  }
  tags = local.tags
}

resource "huaweicloud_nat_gateway" "this" {
  name      = "${var.project_name}-nat"
  spec      = "1"
  vpc_id    = huaweicloud_vpc.this.id
  subnet_id = huaweicloud_vpc_subnet.public[0].id
  tags      = local.tags
}

resource "huaweicloud_nat_snat_rule" "this" {
  nat_gateway_id = huaweicloud_nat_gateway.this.id
  network_id     = huaweicloud_vpc_subnet.private[0].id
  source_type    = 0
  cidr           = var.private_subnet_cidrs[0]
  floating_ip_id = huaweicloud_vpc_eip.nat.id
}

# ---------------------------------------------------------------------------
# 安全组（CCE 节点）
# ---------------------------------------------------------------------------
resource "huaweicloud_networking_secgroup" "node" {
  name        = "${var.project_name}-node-sg"
  description = "CCE 节点安全组"
  tags        = local.tags
}

resource "huaweicloud_networking_secgroup_rule" "node_egress_all" {
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "0"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = huaweicloud_networking_secgroup.node.id
}

resource "huaweicloud_networking_secgroup_rule" "node_ingress_intra" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "0"
  remote_group_id   = huaweicloud_networking_secgroup.node.id
  security_group_id = huaweicloud_networking_secgroup.node.id
}

# ---------------------------------------------------------------------------
# IAM 委托（CCE 访问 VPC / ELB 等云服务）
# ---------------------------------------------------------------------------
resource "huaweicloud_iam_agency" "cce" {
  name                   = "${var.project_name}-cce-agency"
  description            = "CCE 访问其他云服务所需的委托"
  delegated_service_name = "cce"
  domain_roles = [
    "VPC Administrator",
    "ELB Administrator",
  ]
}

# ---------------------------------------------------------------------------
# CCE：集群 + 节点池（原生弹性伸缩）
# ---------------------------------------------------------------------------
resource "huaweicloud_cce_cluster" "this" {
  name                  = "${var.project_name}-cce"
  cluster_type          = "VirtualMachine"
  flavor_id             = "cce.s1.small"
  vpc_id                = huaweicloud_vpc.this.id
  subnet_id             = huaweicloud_vpc_subnet.private[0].id
  enterprise_project_id = "0"
  agency_name           = huaweicloud_iam_agency.cce.name
  cluster_version       = var.cluster_version
  tags                  = local.tags
}

resource "huaweicloud_cce_node_pool" "this" {
  cluster_id         = huaweicloud_cce_cluster.this.id
  name               = "${var.project_name}-nodepool"
  flavor_id          = var.node_flavor
  initial_node_count = var.initial_node_count
  availability_zone  = var.availability_zone
  os                 = "EulerOS 2.9"
  subnet_id          = huaweicloud_vpc_subnet.private[0].id
  security_group_ids = [huaweicloud_networking_secgroup.node.id]

  # 原生弹性伸缩（等价于原 cluster-autoscaler，无需云 API 凭据 / IRSA）
  scaling_enabled = true
  min_node_count  = var.min_node_count
  max_node_count  = var.max_node_count

  root_volume {
    size       = 50
    volumetype = "SAS"
  }
  data_volumes {
    size       = 100
    volumetype = "SAS"
  }

  lifecycle {
    # 运行期弹性伸缩会改写节点数，Terraform 不回滚（C10）
    ignore_changes = [initial_node_count]
  }
  tags = local.tags
}
