output "region" {
  description = "部署区域。"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID。"
  value       = huaweicloud_vpc.this.id
}

output "cce_cluster_id" {
  description = "CCE 集群 ID。"
  value       = huaweicloud_cce_cluster.this.id
}

output "cce_cluster_name" {
  description = "CCE 集群名称（获取 kubeconfig 时使用）。"
  value       = huaweicloud_cce_cluster.this.name
}

output "node_pool_id" {
  description = "CCE 节点池 ID。"
  value       = huaweicloud_cce_node_pool.this.id
}

output "get_kubeconfig_hint" {
  description = "获取 kubeconfig 的方式（需在本地配置 huaweicloud CLI 与凭据）。"
  value       = "hcloud cce kubeconfig get --cluster-name ${huaweicloud_cce_cluster.this.name} --region ${var.region} > ~/.kube/config"
}
