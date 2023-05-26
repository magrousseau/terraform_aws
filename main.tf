terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.38.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}
