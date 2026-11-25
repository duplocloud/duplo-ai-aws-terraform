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

variable "endpoint_public_access" {
  description = "Expose the cluster API on a public endpoint. The app root (Helm and Kubernetes providers) reaches the cluster through it, so turn it off only when OpenTofu runs inside the VPC."
  type        = bool
  default     = true
  nullable    = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public cluster API endpoint. Include the addresses OpenTofu runs from (the DuploCloud agent's egress), or the app root can't reach the cluster."
  type        = list(string)
  default     = ["0.0.0.0/0"]
  nullable    = false

  validation {
    condition     = length(var.endpoint_public_access_cidrs) > 0 && alltrue([for c in var.endpoint_public_access_cidrs : can(cidrhost(c, 0))])
    error_message = "endpoint_public_access_cidrs must be a non-empty list of valid CIDR blocks."
  }
}

variable "node_role_web_identity_subjects" {
  description = "Service-account subjects (system:serviceaccount:<namespace>:<name>, wildcards allowed) that may assume the node role through the cluster's OIDC provider. Empty: none."
  type        = list(string)
  default     = ["system:serviceaccount:helpdesk:*"]
  nullable    = false

  validation {
    condition     = alltrue([for s in var.node_role_web_identity_subjects : startswith(s, "system:serviceaccount:") && s != "system:serviceaccount:*:*"])
    error_message = "Each subject must start with system:serviceaccount: and must not be system:serviceaccount:*:* (every pod in the cluster)."
  }
}
