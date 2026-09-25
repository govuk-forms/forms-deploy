resource "aws_security_group" "grafana" {
  #checkov:skip=CKV2_AWS_5:The security group is attached in ecs.tf
  name        = local.name
  description = "Ingress from the load balancer, egress to the database and the internet"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "ingress_from_alb" {
  description              = "Permit inbound from the load balancer to the container port"
  type                     = "ingress"
  from_port                = local.container_port
  to_port                  = local.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.grafana.id
}

resource "aws_security_group_rule" "egress_to_rds" {
  description              = "Permit outbound to the Grafana database"
  type                     = "egress"
  from_port                = local.rds_port
  to_port                  = local.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.grafana.id
}

resource "aws_security_group_rule" "rds_ingress_from_grafana" {
  description              = "Permit inbound to the database from Grafana"
  type                     = "ingress"
  from_port                = local.rds_port
  to_port                  = local.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana.id
  security_group_id        = aws_security_group.rds.id
}

# GitHub (sign in), grafana.com (plugin install) and the CloudWatch and
# X-Ray APIs, none of which have VPC endpoints in this VPC.
resource "aws_security_group_rule" "egress_to_internet" {
  description       = "Permits outbound 443 to the internet"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.grafana.id
}
