variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Defaults to latest stable if null."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3a.large"
  nullable    = false
}

variable "node_desired" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
  nullable    = false
}

variable "node_min" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
  nullable    = false
}

variable "node_max" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
  nullable    = false
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
  nullable    = false
}

variable "node_ami_type" {
  description = "AMI type for worker nodes"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
  nullable    = false
}

variable "additional_admin_arns" {
  description = "IAM principal ARNs granted AmazonEKSClusterAdminPolicy via EKS access entries"
  type        = list(string)
  default     = []
  nullable    = false
}
