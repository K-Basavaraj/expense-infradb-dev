variable "project_name" {
  default = "expense"
}

variable "environment" {
  default = "dev"
}

variable "common_tags" {
  default = {
    Project     = "expense"
    Terraform   = "true"
    Environment = "dev"
  }
}

variable "zone_name" {
  default = "basavadevops81s.online"
}

variable "zone_id" {
  default = "Z03141913O9KLNEH2KAAM"
}