provider "aws" {
  access_key  = "${var.access_key}"
  secret_key  = "${var.secret_key}"
  region      = "${var.region}"
}

resource "aws_vpc" "default" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  tags { 
    Name = "airpair-example" 
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-airpair-example" 
  public_key = "${file(\"ssh/insecure-deployer.pub\")}"
}
