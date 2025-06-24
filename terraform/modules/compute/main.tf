locals {
  startup_vars = {
    backend_image   = var.backend_image
    db_private_ip   = var.db_private_ip
    db_user         = var.db_user
    db_password     = var.db_password
    db_name         = var.db_name
  }
}



resource "google_compute_instance" "backend_vm" {
  name         = "backend-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  deletion_protection = false

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  tags = ["backend"]

  network_interface {
    subnetwork = var.subnet_id
  }

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # Startup script to install Docker, configure Artifact Registry, pull & run backend
  metadata = {
    "startup-script" = templatefile(
      "${path.module}/startup.tpl.sh",
      local.startup_vars
    )
  }
}
