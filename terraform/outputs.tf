output "config_host" {
  value = "https://${module.gke_cluster.endpoint_dns}"
}

output "cluster_name" {
  value = module.gke_cluster.cluster_name
}

output "node_ip" {
  value = [for node in data.google_compute_instance.nodes : node.network_interface[0].access_config[0].nat_ip]
}