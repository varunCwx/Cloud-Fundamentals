output "db_password_secret_name" {
  value       = module.sql.db_password_secret_name
  description = "Secret Manager secret name for the DB password"
}

output "db_password_secret_id" {
  value       = module.sql.db_password_secret_id
  description = "Secret Manager secret resource ID for the DB password"
}
