variable "db_name" {
  type    = string
  default = "products_test"
}

variable "db_user" {
  type    = string
  default = "postgres_test"
}

variable "db_password" {
  type    = string
  default = "1234"
}

variable "db_instance_name" {
  type    = string
  default = "postgres-instance1"
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "vpc_id" {
  description = "VPC network ID for private SQL connection"
  type        = string
}
