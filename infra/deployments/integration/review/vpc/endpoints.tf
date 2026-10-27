##
# VPC endpoints
#
# Keep traffic to AWS services off the NAT gateways, which charge
# for every GB processed.
##
locals {
  interface_endpoints = {
    ecr_api    = "ecr.api"
    ecr_dkr    = "ecr.dkr"
    cloudwatch = "logs"
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-review"
  description = "Allow ingress from VPC on port 443"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Port 443 from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  egress {
    description = "Port 443 to VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.eu-west-2.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  subnet_ids          = [for s in aws_subnet.private : s.id]

  tags = {
    Name = "review-${each.key}"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.vpc.id
  service_name    = "com.amazonaws.eu-west-2.s3"
  route_table_ids = concat([aws_route_table.public.id], [for rt in aws_route_table.private : rt.id])

  tags = {
    Name = "review-s3"
  }
}
