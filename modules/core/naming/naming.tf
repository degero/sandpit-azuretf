variable "environment" {
  description = "Environment short name, used in resource naming."
  type        = string
}

variable "projectname" {
  description = "Short project/workload name used in resource naming"
  type        = string
}

module "this" {
  source = "github.com/Azure/terraform-azure-avm-utl-naming?ref=7053cb53b29a04e779c1e1e208e51fbbf10edf57"
  # version 0.4.3

  suffix = [var.projectname, var.environment]
}

output "all" {
  description = "All resource naming objects of this module"
  value       = module.this
}
