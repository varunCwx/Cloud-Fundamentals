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