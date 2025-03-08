terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.87"
    }
    # datadog = {
    #   source  = "DataDog/datadog"
    #   version = "~> 3.48"
    # }
    random = {
      version = "~> 3.6"
      source  = "hashicorp/random"
    }
  }
  required_version = "1.10.3"
}
