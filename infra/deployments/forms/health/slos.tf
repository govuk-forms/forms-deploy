locals {
  # Common SLO configuration
  common_burn_rate_configurations = [
    { look_back_window_minutes = 5 },
    { look_back_window_minutes = 30 },
    { look_back_window_minutes = 60 },
    { look_back_window_minutes = 360 },
    { look_back_window_minutes = 4320 }
  ]

  common_goal_config = {
    interval = {
      rolling_interval = {
        duration      = 28
        duration_unit = "DAY"
      }
    }
    warning_threshold = 30.0
  }

  # Availability SLO definitions
  availability_slos = {
    admin_http_availability = {
      name              = "admin-http-availability"
      description       = "99% of requests as measured from the load balancer metrics are successful. Any HTTP status other than 500-599 is considered successful."
      attainment_goal   = 99
      service           = "forms-admin"
      target_group_name = data.aws_lb_target_group.forms_admin_tg.arn_suffix
    }
    runner_http_availability = {
      name              = "runner-http-availability"
      description       = "99% of requests as measured from the load balancer metrics are successful. Any HTTP status other than 500-599 is considered successful."
      attainment_goal   = 99
      service           = "forms-runner"
      target_group_name = data.aws_lb_target_group.forms_runner_tg.arn_suffix
    }
  }

  # Latency SLO definitions
  latency_slos = {
    admin_http_latency_400ms = {
      name              = "admin-http-latency-400ms"
      description       = "90% of requests as measured from the load balancer metrics are under 400ms."
      attainment_goal   = 90
      service           = "forms-admin"
      target_group_name = data.aws_lb_target_group.forms_admin_tg.arn_suffix
      threshold         = "0.4"
    }
    admin_http_latency_1000ms = {
      name              = "admin-http-latency-1000ms"
      description       = "99% of requests as measured from the load balancer metrics are under 1000ms."
      attainment_goal   = 99
      service           = "forms-admin"
      target_group_name = data.aws_lb_target_group.forms_admin_tg.arn_suffix
      threshold         = "1"
    }
    runner_http_latency_200ms = {
      name              = "runner-http-latency-200ms"
      description       = "90% of requests as measured from the load balancer metrics are under 200ms."
      attainment_goal   = 90
      service           = "forms-runner"
      target_group_name = data.aws_lb_target_group.forms_runner_tg.arn_suffix
      threshold         = "0.2"
    }
    runner_http_latency_1000ms = {
      name              = "runner-http-latency-1000ms"
      description       = "99% of requests as measured from the load balancer metrics are under 1000ms."
      attainment_goal   = 99
      service           = "forms-runner"
      target_group_name = data.aws_lb_target_group.forms_runner_tg.arn_suffix
      threshold         = "1"
    }
  }

  # Submission Delivery SLO definitions
  submission_delivery_slos = {
    submission_delivery_latency = {
      name            = "submission-delivery-latency"
      description     = "95% of submission deliveries complete within 1 hour of delivery being triggered."
      attainment_goal = 95
      service         = "forms-runner"
      threshold       = "3600000" # 1 hour in milliseconds
    }
  }
}

# Availability SLOs
resource "awscc_applicationsignals_service_level_objective" "availability" {
  for_each = local.availability_slos

  name        = each.value.name
  description = each.value.description

  request_based_sli = {
    request_based_sli_metric = {
      total_request_count_metric = [
        {
          id = "cwMetricDenominator"
          metric_stat = {
            metric = {
              namespace   = "AWS/ApplicationELB"
              metric_name = "RequestCount"
              dimensions = [
                {
                  name  = "TargetGroup"
                  value = each.value.target_group_name
                },
                {
                  name  = "LoadBalancer"
                  value = data.aws_lb.forms_lb.arn_suffix
                }
              ]
            }
            period = 60
            stat   = "Sum"
          }
          return_data = true
        }
      ]

      monitored_request_count_metric = {
        bad_count_metric = [
          {
            id = "cwMetricNumerator"
            metric_stat = {
              metric = {
                namespace   = "AWS/ApplicationELB"
                metric_name = "HTTPCode_Target_5XX_Count"
                dimensions = [
                  {
                    name  = "TargetGroup"
                    value = each.value.target_group_name
                  },
                  {
                    name  = "LoadBalancer"
                    value = data.aws_lb.forms_lb.arn_suffix
                  }
                ]
              }
              period = 60
              stat   = "Sum"
            }
            return_data = true
          }
        ]
      }
    }
  }

  goal = merge(local.common_goal_config, {
    attainment_goal = each.value.attainment_goal
  })

  burn_rate_configurations = local.common_burn_rate_configurations

  tags = [
    {
      key   = "Environment"
      value = var.environment_name
    },
    {
      key   = "Service"
      value = each.value.service
    }
  ]
}

# Latency SLOs
resource "awscc_applicationsignals_service_level_objective" "latency" {
  for_each = local.latency_slos

  name        = each.value.name
  description = each.value.description

  request_based_sli = {
    request_based_sli_metric = {
      total_request_count_metric = [
        {
          id = "cwMetricDenominator"
          metric_stat = {
            metric = {
              namespace   = "AWS/ApplicationELB"
              metric_name = "TargetResponseTime"
              dimensions = [
                {
                  name  = "TargetGroup"
                  value = each.value.target_group_name
                },
                {
                  name  = "LoadBalancer"
                  value = data.aws_lb.forms_lb.arn_suffix
                }
              ]
            }
            period = 60
            stat   = "SampleCount"
          }
          return_data = true
        }
      ]

      monitored_request_count_metric = {
        good_count_metric = [
          {
            id = "cwMetricNumerator"
            metric_stat = {
              metric = {
                namespace   = "AWS/ApplicationELB"
                metric_name = "TargetResponseTime"
                dimensions = [
                  {
                    name  = "TargetGroup"
                    value = each.value.target_group_name
                  },
                  {
                    name  = "LoadBalancer"
                    value = data.aws_lb.forms_lb.arn_suffix
                  }
                ]
              }
              period = 60
              stat   = "TC(:${each.value.threshold})"
            }
            return_data = true
          }
        ]
      }
    }
  }

  goal = merge(local.common_goal_config, {
    attainment_goal = each.value.attainment_goal
  })

  burn_rate_configurations = local.common_burn_rate_configurations

  tags = [
    {
      key   = "Environment"
      value = var.environment_name
    },
    {
      key   = "Service"
      value = each.value.service
    }
  ]
}

# We need this until https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/2372 is resolved
# If we add any other submission delivery methods, they must be added to this list, otherwise the SLO will not account for them
variable "submission_delivery_methods" {
  description = "List of submission delivery methods configured in this environment"
  type        = list(string)
  default     = ["Email", "S3"]
}

# Submission Delivery SLOs
resource "awscc_applicationsignals_service_level_objective" "submission_delivery" {
  for_each = local.submission_delivery_slos

  name        = each.value.name
  description = each.value.description

  request_based_sli = {
    request_based_sli_metric = {
      # This is how we *should* be doing this. However, CloudFormation does not yet support the period parameter in a MetricDataQuery object, so we have to use the metric_stat approach below.
      # See: https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/2372
      # total_request_count_metric = [
      #   {
      #     id          = "cwMetricDenominator"
      #     expression  = "SUM(SEARCH('{Forms,Environment,SubmissionDeliveryMethod} MetricName=\"SubmissionDeliveryLatency\" Environment=\"${var.environment_name}\"', 'SampleCount', 60))"
      #     return_data = true
      #     period      = 60 # Not currently supported by Cloudformation. Reinstate this once supported.
      #   }
      # ]
      total_request_count_metric = concat(
        # Individual metrics for each delivery method (SampleCount)
        [
          for method in var.submission_delivery_methods : {
            id          = "total_${lower(method)}"
            return_data = false
            metric_stat = {
              metric = {
                metric_name = "SubmissionDeliveryLatency"
                namespace   = "Forms"
                dimensions = [
                  {
                    name  = "Environment"
                    value = var.environment_name
                  },
                  {
                    name  = "SubmissionDeliveryMethod"
                    value = method
                  }
                ]
              }
              period = 60
              stat   = "SampleCount"
            }
          }
        ],
        # SUM expression that combines all total metrics
        [{
          id          = "cwMetricDenominator"
          expression  = "SUM([${join(", ", [for method in var.submission_delivery_methods : "total_${lower(method)}"])}])"
          return_data = true
        }]
      )
      monitored_request_count_metric = {
        # Again, this is how we *should* be doing this. However, CloudFormation does not yet support the period parameter in a MetricDataQuery object, so we have to use the metric_stat approach below.
        # See: https://github.com/aws-cloudformation/cloudformation-coverage-roadmap/issues/2372
        # good_count_metric = [
        #   {
        #     id          = "cwMetricNumerator"
        #     expression  = "SUM(SEARCH('{Forms,Environment,SubmissionDeliveryMethod} MetricName=\"SubmissionDeliveryLatency\" Environment=\"${var.environment_name}\"', 'TC(:${each.value.threshold})', 60))"
        #     return_data = true
        #     period      = 60 # Not currently supported by Cloudformation. Reinstate this once supported.
        #   }
        # ]
        good_count_metric = concat(
          # Individual metrics for each delivery method (percentile count)
          [
            for method in var.submission_delivery_methods : {
              id          = "good_${lower(method)}"
              return_data = false
              metric_stat = {
                metric = {
                  metric_name = "SubmissionDeliveryLatency"
                  namespace   = "Forms"
                  dimensions = [
                    {
                      name  = "Environment"
                      value = var.environment_name
                    },
                    {
                      name  = "SubmissionDeliveryMethod"
                      value = method
                    }
                  ]
                }
                period = 60
                stat   = "TC(:${each.value.threshold})"
              }
            }
          ],
          # SUM expression that combines all good metrics
          [{
            id          = "cwMetricNumerator"
            expression  = "SUM([${join(", ", [for method in var.submission_delivery_methods : "good_${lower(method)}"])}])"
            return_data = true
          }]
        )
      }
    }
  }

  goal = merge(local.common_goal_config, {
    attainment_goal = each.value.attainment_goal
  })

  burn_rate_configurations = local.common_burn_rate_configurations

  tags = [
    {
      key   = "Environment"
      value = var.environment_name
    },
    {
      key   = "Service"
      value = each.value.service
    },
    {
      key   = "Type"
      value = "submission-delivery"
    }
  ]
}
