terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}

variable "project" {
  description = "GCP project ID"
  type        = string
  default     = "varun-verma-cwx-internal"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "backend_image" {
  description = "Artifact Registry path of the backend image"
  type        = string
  default     = "us-central1-docker.pkg.dev/varun-verma-cwx-internal/my-repo2/backend"
}

variable "frontend_image" {
  description = "Artifact Registry path of the frontend image"
  type        = string
  default     = "us-central1-docker.pkg.dev/varun-verma-cwx-internal/my-repo2/frontend"
}

# Enable required Google APIs
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sqladmin" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

# Create a Service Account for VM & GKE
resource "google_service_account" "sa" {
  account_id   = "varun-verma-sa"
  display_name = "Terraform-created service account for VM and GKE"
}

# Grant the Service Account necessary IAM roles
resource "google_project_iam_member" "sa_cloudsql_client" {
  project = var.project
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_artifactregistry_reader" {
  project = var.project
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_container_admin" {
  project = var.project
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_compute_admin" {
  project = var.project
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_serviceaccount_user" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# Use existing private IP range for Cloud SQL (VPC peering)
data "google_compute_global_address" "private_ip_range" {
  name = "default-ip-range"
}

# Establish a VPC peering for the private IP
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = "projects/${var.project}/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [data.google_compute_global_address.private_ip_range.name]
  depends_on              = [google_project_service.servicenetworking]
}

# Create a Cloud SQL (PostgreSQL 14) instance with Private IP
resource "google_sql_database_instance" "db_instance" {
  name             = "postgres-instance"
  database_version = "POSTGRES_14"
  region           = var.region

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      private_network = "projects/${var.project}/global/networks/default"
      ipv4_enabled    = false
    }
  }

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_project_service.sqladmin,
  ]
}

# Create a default database inside the instance
resource "google_sql_database" "appdb" {
  name     = "appdb"
  instance = google_sql_database_instance.db_instance.name
}

# Create a user for the database
resource "google_sql_user" "db_user" {
  name     = "appuser"
  instance = google_sql_database_instance.db_instance.name
  password = "appuser123"  # In production, use a more secure password and consider using Secret Manager
}

# Create a Compute Engine VM running Debian, pulling the backend Docker image
resource "google_compute_instance" "backend_vm" {
  name         = "backend-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

    tags = ["backend"] 

  network_interface {
    network = "default"
    # Give the VM an external IP so you can SSH for troubleshooting
    access_config {}
  }

  service_account {
    email  = google_service_account.sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Startup script to install Docker, configure Artifact Registry, pull & run backend
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    exec > /var/log/startupscript.log 2>&1

    apt-get update
    apt-get install -y apt-transport-https ca-certificates gnupg lsb-release curl

    # Install Google Cloud SDK
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" \
      | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
      | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt-get update
    apt-get install -y google-cloud-sdk docker.io

    # Authenticate Docker for Artifact Registry
    gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet

    BACKEND_IMAGE="${var.backend_image}"
    DB_PRIVATE_IP="${google_sql_database_instance.db_instance.ip_address[0].ip_address}"
    DB_USER="${google_sql_user.db_user.name}"
    DB_PASSWORD="${google_sql_user.db_user.password}"
    DB_NAME="${google_sql_database.appdb.name}"

    # Pull and run backend container
    docker pull "$BACKEND_IMAGE"
    docker run -d \
  --name backend-container \
  -p 5000:5000 \
  -e PORT=5000 \
  -e DB_HOST="$DB_PRIVATE_IP" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_NAME="$DB_NAME" \
  "$BACKEND_IMAGE"
  EOT

  depends_on = [
    google_sql_database_instance.db_instance,
    google_sql_database.appdb,
    google_sql_user.db_user,
    google_project_service.compute,
    google_project_service.artifactregistry,
  ]
}

resource "google_compute_firewall" "allow_backend_5000_internal" {
  name    = "allow-backend-5000-internal"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["10.0.0.0/8"]  # Default VPC and GKE pods/nodes
  target_tags   = ["backend"]
}

# Create a GKE cluster with one node, using the same service account
resource "google_container_cluster" "primary" {
  name               = "frontend-cluster"
  location           = var.zone
  initial_node_count = 1

  network = "default"

  node_config {
    machine_type    = "e2-medium"
    service_account = google_service_account.sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  # Expose the Kubernetes API endpoint publicly
  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = false
  }

  depends_on = [
    google_project_service.container,
  ]
}

# Kubernetes Deployment for the frontend (one replica, listening on port 80)
resource "kubernetes_deployment" "frontend" {
  metadata {
    name   = "frontend-deployment"
    labels = { app = "frontend" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "frontend" }
    }

    template {
      metadata {
        labels = { app = "frontend" }
      }
      spec {
        container {
          name  = "frontend"
          image = var.frontend_image
          port {
            container_port = 80
          }
          
        }
      }
    }
  }

  depends_on = [
    google_container_cluster.primary,
  ]
}

# Kubernetes Service of type LoadBalancer to expose the frontend externally
resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend-service"
    annotations = {
      # Ensure we get a Google Cloud external load balancer
      "cloud.google.com/load-balancer-type" = "External"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.frontend.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }

  depends_on = [
    kubernetes_deployment.frontend,
  ]
}

# Outputs
output "db_private_ip" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.db_instance.ip_address[0].ip_address
}

output "db_name" {
  description = "Name of the created database"
  value       = google_sql_database.appdb.name
}

output "db_user" {
  description = "Database username"
  value       = google_sql_user.db_user.name
}

output "backend_vm_external_ip" {
  description = "External IP of the VM (for SSH access)"
  value       = google_compute_instance.backend_vm.network_interface[0].access_config[0].nat_ip
}

output "backend_vm_internal_ip" {
  value = google_compute_instance.backend_vm.network_interface[0].network_ip
}

output "frontend_service_external_ip" {
  description = "External IP assigned to the Kubernetes LoadBalancer for the frontend"
  value       = kubernetes_service.frontend.status[0].load_balancer[0].ingress[0].ip
}
