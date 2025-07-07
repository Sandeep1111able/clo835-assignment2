provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token      = var.aws_session_token
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "k8s_sg" {
  name        = "k8s-assignment-sg"
  description = "Allow SSH and NodePort traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow NodePort Range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "k8s_ec2" {
  ami                    = "ami-09e6f87a47903347c"  
  instance_type          = "t3.large"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 30            
    volume_type = "gp2"         
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install docker -y
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user

              curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.24.7/2022-10-31/bin/linux/amd64/kubectl
              chmod +x kubectl
              mv kubectl /usr/local/bin/

              curl -Lo kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
              chmod +x kind
              mv kind /usr/local/bin/kind

              echo 'export KUBECONFIG="/home/ec2-user/.kube/config"' >> /home/ec2-user/.bashrc
            EOF

  tags = {
    Name = "CLO835-K8s-Assignment2"
  }
}


resource "aws_ecr_repository" "webapp" {
  name = "webapp"
}

resource "aws_ecr_repository" "mysql" {
  name = "mysql"
}
