terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

#Pega a vpc default
data "aws_vpc" "default" {
  default = true
}

# Pega as subnets da vpc default
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Cria o template de uma instância ec2
resource "aws_launch_template" "app_template" {
  name_prefix  = "app-server-"
  image_id = "ami-0cfde0ea8edd312d4"
  instance_type = "t2.micro"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Ec2Example"
    }
  }
}

# Cria o grupo de autoscaling
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity = 1
  min_size = 1
  max_size = 2

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  # Pega a primeira subnet da lista
  vpc_zone_identifier = [data.aws_subnets.default.ids[0]]

  tag {
    key = "Name"
    value = "Ec2ExampleASG"
    propagate_at_launch = true
  }
}

# Ela aumenta ou diminui a quantidade de instâncias com base no uso médio de CPU.
# Se o uso da CPU estiver em 70%, o ASG vai adicionar outra CPU
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name = "cpu-target-tracking"
  policy_type = "TargetTrackingScaling"
  estimated_instance_warmup = 60
  autoscaling_group_name = aws_autoscaling_group.app_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
