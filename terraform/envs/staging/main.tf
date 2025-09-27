data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name        = "hackathon-vpc-${var.env_name}"
    Environment = var.env_name
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name        = "public-subnet-${var.env_name}-${count.index + 1}"
    Environment = var.env_name
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name        = "private-subnet-${var.env_name}-${count.index + 1}"
    Environment = var.env_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "hackathon-igw-${var.env_name}"
    Environment = var.env_name
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name        = "hackathon-public-rt-${var.env_name}"
    Environment = var.env_name
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name        = "hackathon-nat-eip-${var.env_name}"
    Environment = var.env_name
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name        = "hackathon-nat-gw-${var.env_name}"
    Environment = var.env_name
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name        = "hackathon-private-rt-${var.env_name}"
    Environment = var.env_name
  }
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Jenkins SG & instance (you can restrict ingress CIDR later per env)
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg-${var.env_name}"
  description = "Allow SSH and Jenkins"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env_name
  }
}

resource "aws_instance" "jenkins" {
  ami                    = var.ec2_jenkins_ami
  instance_type          = var.ec2_instance_type
  key_name               = "build"                                 # keep your key
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  subnet_id              = aws_subnet.public[0].id
  associate_public_ip_address = true
  tags = {
    Name        = "Jenkins-Server-${var.env_name}"
    Environment = var.env_name
  }
  depends_on = [aws_vpc.main, aws_security_group.jenkins_sg]
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg-${var.env_name}"
  description = "Allow SSH from your IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["103.39.127.0/24"]   # change to your IP range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.env_name
  }
}

resource "aws_instance" "bastion" {
  ami                         = "ami-00ca32bbc84273381"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = "build"
  tags = {
    Name        = "Bastion-Host-${var.env_name}"
    Environment = var.env_name
  }
}

# ECR repos per env (so each env has its own repo if you prefer)
resource "aws_ecr_repository" "patient" {
  name = "${var.env_name}-patient-repo"
}

resource "aws_ecr_repository" "appointment" {
  name = "${var.env_name}-appointment-repo"
}

# EKS module w/ Fargate profiles — cluster name suffixed with env
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = "${var.eks_cluster_name}-${var.env_name}"
  cluster_version = "1.29"

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        { namespace = "default" },
        { namespace = "patient" },
        { namespace = "appointments" }
      ]
    }
  }



  tags = {
    Environment = var.env_name
  }

  depends_on = [aws_nat_gateway.nat]
}

# Outputs per env
output "env" {
  value = var.env_name
}
output "eks_cluster_name" {
  value = module.eks.cluster_id
}
output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}
output "patient_ecr_repo_uri" {
  value = aws_ecr_repository.patient.repository_url
}
output "appointment_ecr_repo_uri" {
  value = aws_ecr_repository.appointment.repository_url
}
