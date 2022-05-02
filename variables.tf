variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "vpc_azs" {
  description = "Availability zones for VPC"
  type        = list(string)

  validation {
    condition = length(var.vpc_azs) > 1
    error_message = "You must specify at least 2 availability zones."
  }
}

variable "vpc_private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)

  validation {
    condition = length(var.vpc_private_subnets) > 1
    error_message = "You must specify at least 2 private subnets."
  }
}

variable "vpc_public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)

  validation {
    condition = length(var.vpc_public_subnets) > 1
    error_message = "You must specify at least 2 public subnets."
  }
}
