# # Data source to retrieve the current Google client configuration
# data "google_client_config" "current" {}

# # Data source to fetch details about the created GKE cluster
# data "google_container_cluster" "main" {
#   # Name of the cluster
#   name = module.gke_cluster.cluster_name
#   # Location (region)
#   location = var.GOOGLE_REGION
# }

# data "google_compute_instance_group" "node_instance_groups" {
#   self_link = module.gke_cluster.managed_instance_group_urls
# }

# data "google_compute_instance" "nodes" {
#   for_each  = toset(data.google_compute_instance_group.node_instance_groups.instances[*])
#   self_link = each.key
# }