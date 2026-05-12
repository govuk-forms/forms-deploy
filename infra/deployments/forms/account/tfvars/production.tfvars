account_name          = "production"
aws_account_id        = "443944947292"
environment_name      = "production"
environment_type      = "production"
require_vpn_to_access = true
apex_domain           = "forms.service.gov.uk"
dns_delegation_records = {
  "dev.forms.service.gov.uk" = [
    "ns-124.awsdns-15.com",
    "ns-1371.awsdns-43.org",
    "ns-2043.awsdns-63.co.uk",
    "ns-593.awsdns-10.net",
  ],

  "staging.forms.service.gov.uk" = [
    "ns-1162.awsdns-17.org",
    "ns-1604.awsdns-08.co.uk",
    "ns-359.awsdns-44.com",
    "ns-638.awsdns-15.net",
  ],
  "tools.forms.service.gov.uk" = [
    "ns-466.awsdns-58.com",
    "ns-1524.awsdns-62.org",
    "ns-945.awsdns-54.net",
    "ns-1874.awsdns-42.co.uk",
  ],
  "review.forms.service.gov.uk" = [
    "ns-1234.awsdns-26.org",
    "ns-1730.awsdns-24.co.uk",
    "ns-266.awsdns-33.com",
    "ns-785.awsdns-34.net",
  ]
}
codestar_connection_arn   = "arn:aws:codeconnections:eu-west-2:443944947292:connection/a2c94a66-2c03-45db-bb18-5c37f8b44531"
deploy_account_id         = "711966560482"
pentester_email_addresses = []
pentester_cidr_ranges     = []
