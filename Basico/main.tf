# Provider
provider "aws" {
    profile = "default"
    region = "us-east-1"
}

# Resources
resource "aws_instance" "app_server" {
    ami = "ami-091d7d61336a4c68f"
    instance_type = var.ec2_instance_type

    tags = {
      Name = var.instance_name
    }
}