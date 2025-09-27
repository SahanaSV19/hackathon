variable "env_name" {
  description = "Environment name"
  default     = "staging"      
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "eks_cluster_name" {
  description = "Base cluster name (will be suffixed with env)"
  default     = "hackathon-eks"
}

variable "ec2_jenkins_ami" {
  default = "ami-0bbdd8c17ed981ef9"
}

variable "ec2_instance_type" {
  default = "t3.medium"
}
