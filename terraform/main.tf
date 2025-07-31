provider "aws" {
  region = var.aws_region
}

# Upload your public key so you can SSH
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# Security group allowing SSH + HTTPS
resource "aws_security_group" "app_sg" {
  name        = "vault-demo-sg"
  description = "Allow SSH and HTTPS"
  ingress = [
    { description = "SSH", from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { description = "HTTPS", from_port = 8443, to_port = 8443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
  ]
  egress = [
    { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] },
  ]
}

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  # Bootstrap with Docker, Docker-Compose, and your app
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              systemctl start docker
              usermod -a -G docker ec2-user

              # Install docker-compose
              curl -Lo /usr/local/bin/docker-compose \
                   "https://github.com/docker/compose/releases/download/2.14.0/docker-compose-$(uname -s)-$(uname -m)"
              chmod +x /usr/local/bin/docker-compose

              # Clone your demo repo (or copy files here)
              cd /home/ec2-user
              git clone https://github.com/youruser/vault-demo-app.git app
              cd app

              # Export Vault vars for the container
              export VAULT_ADDR=${var.vault_addr}
              export VAULT_TOKEN=${var.vault_token}

              # Start the stack
              docker-compose up -d --build
              EOF

  tags = {
    Name = "vault-demo-app"
  }
}
