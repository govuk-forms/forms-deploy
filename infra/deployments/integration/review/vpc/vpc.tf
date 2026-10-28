resource "aws_vpc" "vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "review"
  }
}

// This ensures the default security group provides no ingress or egress
resource "aws_default_security_group" "no_access" {
  vpc_id = aws_vpc.vpc.id
}
