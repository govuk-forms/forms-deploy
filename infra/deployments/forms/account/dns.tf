resource "aws_route53_zone" "public" {
  #checkov:skip=CKV2_AWS_38:DNSSEC is not currently necessary
  #checkov:skip=CKV2_AWS_39:DNS query logging not necessary
  name = "${var.apex_domain}."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "domain_delegations" {
  for_each = var.dns_delegation_records
  zone_id  = aws_route53_zone.public.id
  name     = each.key
  type     = "NS"
  ttl      = 60
  records  = each.value
}

resource "aws_route53_zone" "internal_digital" {
  #checkov:skip=CKV2_AWS_38:DNSSEC is not currently necessary
  #checkov:skip=CKV2_AWS_39:DNS query logging not necessary
  name = "${var.internal_apex_domain}."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "internal_domain_delegations" {
  for_each = var.internal_dns_delegation_records
  zone_id  = aws_route53_zone.internal_digital.id
  name     = each.key
  type     = "NS"
  ttl      = 60
  records  = each.value
}

# Create a dummy VPC for the internal zone
# This is used to create the internal zone in the account,
# before the real VPC is available from the environment deployment
resource "aws_vpc" "dummy_internal_zone" {
  #checkov:skip=CKV2_AWS_11:This is a dummy VPC only used for zone creation
  #checkov:skip=CKV2_AWS_12:This is a dummy VPC only used for zone creation
  #checkov:skip=CKV_AWS_60:This is a dummy VPC only used for zone creation
  cidr_block           = "172.30.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dummy-internal-zone-${var.environment_name}"
  }
}

# Create the internal zone with the dummy VPC
# The deployer will later reassociate this with the real VPC in the environment deployment
resource "aws_route53_zone" "private_internal" {
  #checkov:skip=CKV2_AWS_38:DNSSEC is not currently necessary for private zones
  #checkov:skip=CKV2_AWS_39:DNS query logging not necessary for private zones
  name = "internal.${var.apex_domain}."

  vpc {
    vpc_id = aws_vpc.dummy_internal_zone.id
  }

  lifecycle {
    prevent_destroy = true
    # Ignore VPC changes as they will be managed by the deployer
    ignore_changes = [vpc]
  }
}
