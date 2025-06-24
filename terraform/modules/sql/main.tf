# 2️⃣ Create the Cloud SQL Postgres instance
resource "google_sql_database_instance" "postgres" {
  name                = var.db_instance_name
  database_version    = "POSTGRES_14"
  region              = var.region
  deletion_protection = false

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
    }
  }

  
}

resource "google_sql_database" "appdb" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}



# 1️⃣ Generate a strong random password
resource "random_password" "db_password" {
  length           = 16
  override_special = "!@#$%^&*()-_+="
  special          = true
}

# 2️⃣ Vault it in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.db_instance_name}-db-password"
  replication {
    auto  {}
  }
}

resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data_wo = random_password.db_password.result
}



resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password_wo = random_password.db_password.result
}
# 3️⃣ Expose the secret’s resource name so other modules (or CI/CD) can pull it
output "db_password_secret_name" {
  description = "Secret Manager secret name (use with Secret Manager API or CSI Driver)"
  value       = google_secret_manager_secret.db_password.secret_id
}

output "db_password_secret_id" {
  description = "Resource ID of the Secret Manager secret"
  value       = google_secret_manager_secret.db_password.id
}
