variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  description = "The GCP zone for the GKE cluster nodes and VM."
  type        = string
}


variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "app-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "app-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
  default     = "10.10.0.0/16"
}