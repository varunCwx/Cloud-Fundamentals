output "cluster_endpoint" {
  description = "The endpoint for the GKE control plane"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded CA certificate for the cluster"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
}

output "frontend_lb_ip" {
  description = "External IP of the frontend LoadBalancer Service"
  value       = kubernetes_service.frontend.status[0].load_balancer[0].ingress[0].ip
}
