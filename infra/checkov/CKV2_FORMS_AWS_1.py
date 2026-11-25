from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


# This was a YAML check, but from Checkov 3.4 the graph operators it used report
# an alarm_actions that is a reference to a value containing "form" (such as
# "govuk-forms-alert") as not set. The resource's own configuration is
# unaffected, so the check reads that instead.
class CKV2_FORMS_AWS_1(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Check that all CloudWatch metric alarms have an alarm action set",
            id="CKV2_FORMS_AWS_1",
            categories=[CheckCategories.CONVENTION],
            supported_resources=["aws_cloudwatch_metric_alarm"],
        )

    def scan_resource_conf(self, conf):
        actions = conf.get("alarm_actions")

        # Each attribute is wrapped in a list, so [] is [[]]. A reference that
        # Checkov can't resolve is left as a string, which counts as set.
        if not actions or actions[0] in ([], None, ""):
            return CheckResult.FAILED
        return CheckResult.PASSED


check = CKV2_FORMS_AWS_1()
