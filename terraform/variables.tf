variable "public_subnet_cidrs" {
   type = list(string)
   description = "Public Subnet CIDR values"
   default = [ "10.0.1.0/24", "10.0.2.0/24" ]
}


variable "lambda_subnet_cidrs" {
    type = list(string)
    description = "Lambda Subnet CIDR values"
    default = [ "10.0.3.0/24", "10.0.4.0/24" ]
}

variable "database_subnet_cidrs" {
    type = list(string)
    description = "Database Subnet CIDR values"
    default = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "azs" {
  type = list(string)
  description = "Availability Zones"
  default = [ "us-east-1a", "us-east-1b" ]
}