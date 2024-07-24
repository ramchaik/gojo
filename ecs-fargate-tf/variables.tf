variable "db_username" {
  description = "Username for the RDS instance"
}

variable "db_password" {
  description = "Password for the RDS instance"
  sensitive   = true
}

variable "liveblocks_secret" {
  description = "Liveblocks secret key"
  sensitive   = true
}
