variable "deployment" {
  description = "Deployment identity: { name, region, host, xterm_host, account_id }"
  type = object({
    name       = string
    region     = string
    host       = string
    xterm_host = string
    account_id = string
  })
}

# Each layer: { mode, values, provides }
#   mode     "create" runs the module; "existing" adopts (module count = 0).
#   values   module arguments, read with try(var.<layer>.values.<name>, null)
#   provides outputs of the adopted resource, used when the module is not created.
# dns modes: "route53" | "certificate" | "external" (module runs for route53 and external).
variable "network" {
  description = "VPC layer"
  type        = any
}

variable "cluster" {
  description = "EKS cluster layer"
  type        = any
}

variable "efs" {
  description = "EFS layer"
  type        = any
}

variable "buckets" {
  description = "S3 buckets layer"
  type        = any
}

variable "dns" {
  description = "DNS / certificate layer"
  type        = any
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
