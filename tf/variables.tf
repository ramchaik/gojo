variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS instance"
  type        = string
}

variable "liveblocks_secret" {
  description = "Secret for liveblocks"
  type        = string
}
