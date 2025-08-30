output "config_host" {
  value = "https://${module.gke_cluster.endpoint_dns}"
}

# output "config_token" {
#   value     = data.google_client_config.current.access_token
#   sensitive = true
# }

# output "config_ca" {
#   value = base64decode(
#     data.google_container_cluster.main.master_auth[0].cluster_ca_certificate,
#   )
# }

output "cluster_name" {
  value = module.gke_cluster.cluster_name
}

# output "node_ip" {
#   value = [for node in data.google_compute_instance.nodes : node.network_interface[0].access_config[0].nat_ip]
# }