module "gke_cluster" {
  source = "github.com/Makushchenko/tf-google-gke-cluster"

  GOOGLE_REGION           = var.GOOGLE_REGION
  GOOGLE_PROJECT          = var.GOOGLE_PROJECT
  GKE_CLUSTER_NAME        = var.GKE_CLUSTER_NAME
  GKE_DELETION_PROTECTION = var.GKE_DELETION_PROTECTION
  GKE_POOL_NAME           = var.GKE_POOL_NAME
  GKE_MACHINE_TYPE        = var.GKE_MACHINE_TYPE
  GKE_DISK_SIZE_GB        = var.GKE_DISK_SIZE_GB
  GKE_NUM_NODES           = var.GKE_NUM_NODES
}