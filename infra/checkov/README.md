# Custom Checkov checks

Each check is named after its ID: `CKV2_FORMS_AWS_<n>`. Take the next number
after the highest one among the check files in this directory and the retired
IDs in this table, never a gap.

Checkov has no way to reserve an ID, so retired ones are listed here. Don't
reuse them: a `#checkov:skip=` comment for an old check would silently apply
to the new one.

| ID | Status |
|----|--------|
| `CKV2_FORMS_AWS_4` | Retired. It checked that an autoscaling minimum was not above the maximum, which Checkov could not resolve from tfvars. `forms_*_settings` validates this now. |
| `CKV2_FORMS_AWS_5` | Retired. It checked an autoscaling minimum that Checkov never resolved, so it evaluated nothing. `ecs-service` validates `scaling_rules.min_capacity` instead. |
