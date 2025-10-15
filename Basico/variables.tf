 variable "instance_name" {
   description = "Value of the Name tag for the EC2 instance"
   type = string
   default = "MyInstance"
 }

 variable "ec2_instance_type" {
   description = "AWS EC2 Instance Type"
   type = string
   default = "t2.micro"
 }