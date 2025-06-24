output "db_name" {
  value = google_sql_database.appdb.name
}

output "username" {
  value = google_sql_user.user.name
}

output "instance_name" {
  value = google_sql_database_instance.postgres.name
}

output "db_private_ip" {
  value = google_sql_database_instance.postgres.private_ip_address
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}

