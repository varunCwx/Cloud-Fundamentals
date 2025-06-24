resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = var.location
  network            = var.network
  subnetwork         = var.subnetwork

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection = false
  private_cluster_config {
    enable_private_nodes    = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  master_auth {
    
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = var.node_pool_name
  location   = var.location
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    machine_type = var.machine_type
    image_type   = "COS_CONTAINERD"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  
}

data "google_client_config" "default" {}



resource "kubernetes_deployment" "frontend" {
  depends_on = [ google_container_node_pool.primary_nodes ]
  metadata {
    name   = "frontend"
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
          name  = "nginx-frontend"
          image = var.frontend_image

          port {
            container_port = var.frontend_port
            
          }

          env {
            name  = "BACKEND_URL"
            value = var.backend_host
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend"
  }

  spec {
    selector = { app = kubernetes_deployment.frontend.spec[0].template[0].metadata[0].labels.app }

    port {
      port        = var.frontend_port
      target_port = var.frontend_port
    }

    type = "LoadBalancer"
  }
}