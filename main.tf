provider "aws" {
	region = "us-east-1"
}

#create a dedicated vpc
resource "aws_vpc" "main" {
        cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.main.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}


# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "terraform_vpc_example"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.main.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#https://github.com/terraform-providers/terraform-provider-aws/blob/master/examples/two-tier/main.tf

resource "aws_security_group" "instance" {
  name        = "terraform-example-instance"
  vpc_id      = "${aws_vpc.main.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = "${var.server_port}"
    to_port     = "${var.server_port}"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description = "The port that will be used to serve HTTP requests"
  default = 8080
}

resource "aws_instance" "example" {
	ami = "ami-40d28157"
	instance_type = "t2.micro"
	vpc_security_group_ids = ["${aws_security_group.instance.id}"]
	subnet_id = "${aws_subnet.public.id}"
  tags {
    Name = "terraform-example"
  }
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
}

output "public_ip" {
  value = "${aws_instance.example.public_ip}"
}
