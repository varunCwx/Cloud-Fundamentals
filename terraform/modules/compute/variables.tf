variable "project_id" {
    description = "GCP Project ID"
    type = string
}

variable "region" {
    description = "GCP region"
    type = string
    default = "us-central1"
}

variable "zone" {
  description = "GCP zone to deploy VM into"
  type        = string
  default     = "us-central1-a"
}

variable "backend_image" {
  description = "Artifact Registry path of the backend image"
  type        = string
  default     = "us-central1-docker.pkg.dev/varun-verma-cwx-internal/my-repo2/backend"
}

variable "subnet_id" {
  description = "ID of the subnet for the VM"
  type        = string
}

variable "service_account_email" {
  description = "Email of the service account for the VM"
  type        = string
}

variable "db_private_ip" {
  description = "Private IP address of the database instance"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}


