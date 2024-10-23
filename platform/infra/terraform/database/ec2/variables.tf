variable "vpc_id" {
  type        = string
  description = "VPC ID of the EKS Cluster"
}
variable "vpc_private_subnets" {
  type        = list(string)
  description = "VPC SubnetId of the EKS Cluster"
  default     = []
}
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "ws-dev"
}

variable "key_name" {
  description = "The name of the key pair to use for the EC2 instance"
  type        = string
}