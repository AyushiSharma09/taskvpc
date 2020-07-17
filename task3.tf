#PROVISIONED AWS AS PROVIDER

provider "aws" {
    region ="ap-south-1"
}

#CREATED VPC

resource "aws_vpc" "myvpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main-vpc"
  }
}

#CREATED PUBLIC SUBNET  

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

   tags = {
    Name = "public-1a"
  }
}

#CREATED PRIVATE SUBNET
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
  
  tags = {
    Name = "private-1b"
  }
}

#CREATED A PUBLIC FACING INTERNET GATEWAY

resource "aws_internet_gateway" "int-gat" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "my-int-gat"
  }
}

#CREATED A ROUTE TABLE FOR INTERNET GATEWAY AND ADDED ROUTE SO THAT EVERYONE CAN CONNECT TO THE INSTANCE USING INTERNET GATEWAY
resource "aws_route_table" "route-tab" {
  vpc_id = "${aws_vpc.myvpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.int-gat.id}"
  }
  
  tags = {
    Name = "route-public"
  }
}
resource "aws_route_table_association" "subnet1-asso" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route-tab.id
}

#CREATED KEY

resource "tls_private_key" "mykey"{
 algorithm = "RSA"
}

module "key_pair"{
 source ="terraform-aws-modules/key-pair/aws"
 key_name = "new_key"
 public_key = tls_private_key.mykey.public_key_openssh
}

#CREATED SECURITY GROUP FOR WORDPRESS WITH CLIENT ACCESSABLE SETTINGS
resource "aws_security_group" "new_sg" {
  name        = "allow-ports-wp"
  description = "Allow https and ssh"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name ="allow-ports-wp"
  }
}

#LAUNCHING INSTANCE
resource "aws_instance" "os1" {
      ami                = "ami-7e257211"
      instance_type = "t2.micro"
      key_name       = "new_key"
      vpc_security_group_ids =[aws_security_group.new_sg.id]
      subnet_id       = aws_subnet.subnet1.id
 
  tags = {
    Name = "wp-os"
  }
}


#SECURITY GROUP FOR MYSQL DATABASE ALLOWING PORT 3306 IN PVT. SUBNET SO THAT OUR WORDPRESS CAN CONNECT WITH THE SAME 

resource "aws_security_group" "new_sg2" {
  name        = "allow-ports-mysql"
  description = "Allow muysql"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 0
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name ="allow-ports-mysql"
  }
}

#LAUNCHED EC2 INSTANCE HAVING MYSQL SETUP ALREADY WITH ABOVE SECURITY GROUP
resource "aws_instance" "os2" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name = "new_key"
  vpc_security_group_ids =[aws_security_group.new_sg2.id]
  subnet_id = aws_subnet.subnet2.id
 

  tags = {
    Name = "mysql-os"
  }
}