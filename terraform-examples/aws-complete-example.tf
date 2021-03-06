provider "aws" 
{
  region = "${var.region}"
  profile = "${var.profile}"  
  access_key = "AKIAIL3URTBNUIAP4BYQ"
  secret_key = "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"

}

resource "aws_vpc" "vpc" 
{
  cidr_block = "172.30.0.0/16"
}

# Create an internet gateway to give our subnet access to the open internet
resource "aws_internet_gateway" "internet-gateway" 
{
  vpc_id = "${aws_vpc.vpc.id}"
}

# Give the VPC internet access on its main route table
resource "aws_route" "internet_access" 
{
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.internet-gateway.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" 
{
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "172.30.1.0/24"
  map_public_ip_on_launch = true

  tags 
  {
    Name = "Public"
  }
}

# Our default security group to access
# instances over SSH and HTTP
resource "aws_security_group" "default" 
{
  name        = "terraform-securitygroup"
  description = "Used for public instances created from Terraform"
  vpc_id      = "${aws_vpc.vpc.id}"

  # SSH access from anywhere
  ingress 
  {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress 
  {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["172.30.0.0/16"]
  }

  # outbound internet access
  egress 
  {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" 
{
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "web" 
{
  instance_type = "t2.micro"
  ami = "ami-03291866"

  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  # We're going to launch into the public subnet for this.
  # Normally, in production environments, webservers would be in
  # private subnets.
  subnet_id = "${aws_subnet.default.id}"

  # The connection block tells our provisioner how to
  # communicate with the instance
  connection 
  {
    user = "ec2-user"
  }

  # We run a remote provisioner on the instance after creating it 
  # to install Nginx. By default, this should be on port 80
  provisioner "remote-exec" 
  {
    inline = 
	[
      "sudo yum -y update",
      "sudo yum -y install nginx",
      "sudo service nginx start", 
      "sudo yum -y install docker",
	  "sudo service docker start",
	  "sudo groupadd docker && sudo usermod -aG docker ec2-user"
    ]
  }
}

