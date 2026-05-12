module "waf_protection" {
  source = "../../../../modules/alb_waf_protection"

  alb_arn                       = aws_lb.load_balancer.arn
  environment_name              = "review"
  send_logs_to_cyber            = var.send_logs_to_cyber
  kinesis_subscription_role_arn = var.kinesis_subscription_role_arn
  anti_ddos_exempt_uri_regular_expressions = [
    "^/up$",
    "^/api(/.*)?$",
  ]
}
