output "backend_vm_dns" {
  value = "${google_compute_instance.backend_vm.name}.c.${var.project_id}.internal"
}

output "backend_vm_internal_ip" {
  value = google_compute_instance.backend_vm.network_interface[0].network_ip
}