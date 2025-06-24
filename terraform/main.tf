# Enable required APIs
resource "google_project_service" "compute" {
  project                    = var.project_id
  service                    = "compute.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "sql" {
  project = var.project_id
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}


resource "google_project_service" "artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "servicenetworking" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"
}

resource "google_project_service" "gke" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

#service account creation and binding 
resource "google_service_account" "compute_sa" {
  account_id   = "compute-sa"
  display_name = "Service account for compute VMs"
}

resource "google_project_iam_binding" "sa_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"

  members = [
    "serviceAccount:${google_service_account.compute_sa.email}",
  ]
}

resource "google_project_iam_binding" "sa_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"

  members = [
    "serviceAccount:${google_service_account.compute_sa.email}",
  ]
}

module "sql" {
  source      = "./modules/sql"
  project_id  = var.project_id
  region      = var.region
  db_password = module.sql.db_password
  vpc_id      = google_compute_network.app_vpc.id

  depends_on = [
    google_service_networking_connection.private_vpc_conn,
    google_project_service.secretmanager
  ]
}

# networking 
resource "google_compute_network" "app_vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

# 2️⃣ A regional subnet in that VPC
resource "google_compute_subnetwork" "app_subnet" {
  name          = var.subnet_name
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.app_vpc.id
  ip_cidr_range = var.subnet_cidr

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

# 3️⃣ Reserve a /16 range for Cloud SQL private IP peering
resource "google_compute_global_address" "sql_private_range" {
  name          = "sql-private-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.app_vpc.id
}



# 4️⃣ Peer that range into the Service Networking API
resource "google_service_networking_connection" "private_vpc_conn" {
  network                 = google_compute_network.app_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.sql_private_range.name]

  depends_on = [
    google_project_service.servicenetworking
  ]
}

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  project = var.project_id
  region  = var.region

  network = google_compute_network.app_vpc.id
}

resource "google_compute_router_nat" "nat_config" {
  name    = "nat-config"
  project = var.project_id
  region  = var.region
  router  = google_compute_router.nat_router.name

  # Let Google auto-allocate NAT IP addresses
  nat_ip_allocate_option = "AUTO_ONLY"

  # Send all subnet IPs, including primary and secondary ranges, through this NAT
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"


}

resource "google_compute_firewall" "allow_pods_to_backend" {
  name    = "allow-pods-to-backend"
  project = var.project_id
  network = google_compute_network.app_vpc.self_link

  direction     = "INGRESS"
  target_tags   = ["backend"]
  source_ranges = ["0.0.0.0/0"] # opens from anywhere—but only VPC-internal traffic will reach your VM since it has no public IP

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }
}


# moduling 


module "compute" {
  source                = "./modules/compute"
  project_id            = var.project_id
  region                = var.region
  zone                  = var.zone
  subnet_id             = google_compute_subnetwork.app_subnet.id
  service_account_email = google_service_account.compute_sa.email
  db_private_ip         = module.sql.db_private_ip
  db_user               = module.sql.username
  db_password           = module.sql.db_password
  db_name               = module.sql.db_name

  depends_on = [
    module.sql,
    google_service_networking_connection.private_vpc_conn
  ]
}

module "gke" {
  source                        = "./modules/gke"
  cluster_name                  = "frontend-cluster"
  location                      = var.region
  network                       = google_compute_network.app_vpc.name
  subnetwork                    = google_compute_subnetwork.app_subnet.name
  master_ipv4_cidr_block        = "172.16.0.0/28"
  pods_secondary_range_name     = "pods"
  services_secondary_range_name = "services"
  node_pool_name                = "primary-pool"
  node_count                    = 1
  machine_type                  = "e2-micro"
  frontend_image                = "us-central1-docker.pkg.dev/varun-verma-cwx-internal/my-repo2/frontend"
  frontend_port                 = 80
  backend_host                  = module.compute.backend_vm_internal_ip

  depends_on = [
    google_project_service.gke,
    module.compute
  ]
}


