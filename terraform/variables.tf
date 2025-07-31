variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "EC2 AMI (must include Docker)"
  type        = string
  # Amazon Linux 2 in us-east-1
  default     = "ami-0c2b8ca1dad447f8a"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of an existing AWS key pair"
  type        = string
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vault_addr" {
  description = "Address of your Vault server (for the Vault provider)"
  type        = string
}

variable "vault_token" {
  description = "Root token for Vault provider"
  type        = string
  sensitive   = true
}

variable "db_root_username" {
  description = "MySQL root user"
  type        = string
  default     = "root"
}

variable "db_root_password" {
  description = "MySQL root password"
  type        = string
  default     = "rootpassword"
}
