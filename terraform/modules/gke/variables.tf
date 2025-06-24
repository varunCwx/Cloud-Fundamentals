variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  
}

variable "location" {
  description = "Region or zone for the GKE cluster (e.g. us-central1)"
  type        = string
  
}

variable "network" {
  description = "VPC network name or self_link"
  type        = string
 
}

variable "subnetwork" {
  description = "Subnetwork name or self_link"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for master network (private cluster)"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Secondary range for GKE pods"
  type        = string
}

variable "services_secondary_range_name" {
  description = "Secondary range for GKE services"
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
  default     = "primary-pool"
}

variable "node_count" {
  description = "Number of nodes in the pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-micro"
}

variable "frontend_image" {
  description = "Artifact Registry image for the frontend"
  type        = string
  default     = "us-central1-docker.pkg.dev/varun-verma-cwx-internal/my-repo2/frontend"
}

variable "frontend_port" {
  description = "Port the frontend container listens on"
  type        = number
  default     = 80
}

variable "backend_host" {
  description = "Internal DNS name or IP of backend VM"
  type        = string
  default = "http://backend-vm.c.varun-verma-cwx-internal.internal:5000"
}
