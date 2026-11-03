variable "region" {
  description = "部署区域。"
  type        = string
  default     = "cn-north-4"
}

variable "project_name" {
  description = "资源统一前缀。"
  type        = string
  default     = "cce-fluxv2-gitops-example"
}

variable "vpc_cidr" {
  description = "VPC 网段。"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "公网子网（NAT / 入口 ELB）。"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "私网子网（CCE 节点落位）。"
  type        = list(string)
  default     = ["10.10.11.0/24", "10.10.12.0/24"]
}

variable "cluster_version" {
  description = "CCE 集群 Kubernetes 版本。"
  type        = string
  default     = "v1.31"
}

variable "node_flavor" {
  description = "CCE 节点池计算规格（已核验 cn-north-4a 可售）。"
  type        = string
  default     = "s6.large.2"
}

variable "availability_zone" {
  description = "节点池可用区。"
  type        = string
  default     = "cn-north-4a"
}

variable "initial_node_count" {
  description = "节点池初始节点数（运行期由弹性伸缩改写，故 ignore_changes）。"
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "节点池弹性伸缩下限（等价于原 aws 节点组 minSize）。"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "节点池弹性伸缩上限（等价于原 aws 节点组 maxSize）。"
  type        = number
  default     = 20
}
