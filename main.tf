terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.38.0"
    }
  }
  cloud {
      organization = "magrousseau"

      workspaces {
        name = "gh-actions"
      }
    }
}


provider "aws" {
  region = "eu-west-1"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

data "aws_ami" "ubuntu" {

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

## Retrieve default VPC

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_launch_configuration" "launch" {
  name_prefix     = "asg-ec2-launch-config"
  image_id        =  data.aws_ami.ubuntu.id
  instance_type   = "t2.micro"
  user_data = "${file("install.sh")}"
  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "cluster" {
  min_size = 2
  max_size = 3
  desired_capacity = 2
  launch_configuration = aws_launch_configuration.launch.name
  vpc_zone_identifier = data.aws_subnets.default.ids

}

resource "aws_lb" "lb" {
  name               = "guest-app"
  internal           = false
  load_balancer_type = "application"

}

resource "aws_lb_target_group" "guest-app-cluster" {
   name     = "guest-app"
   port     = 5000
   protocol = "HTTP"
   vpc_id = data.aws_vpc.default.id
 }
resource "aws_autoscaling_attachment" "guest-app" {
  autoscaling_group_name = aws_autoscaling_group.cluster.id
  alb_target_group_arn   = aws_lb_target_group.guest-app-cluster.arn
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.guest-app-cluster.arn
  }
}
