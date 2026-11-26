from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
import os

class CKV2_FORMS_AWS_8(BaseResourceCheck):
    def __init__(self):
        # This is the full description of your check
        description = "Check that ALB listener rule priorities are distinct for all aws_lb_listener_rule within the same directory"

        # This is the Unique ID for your check
        id = "CKV2_FORMS_AWS_8"

        # These are the terraform objects supported by this check (ex: aws_iam_policy_document)
        supported_resources = ['aws_lb_listener_rule']

        # Valid CheckCategories are defined in checkov/common/models/enums.py
        categories = [CheckCategories.NETWORKING]

        # [directory] => [listener_arn] => [priority] => entity_path of the rule
        self.encountered_priorities = {}

        super().__init__(name=description, id=id, categories=categories, supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        file_name = self.entity_path.split(":")[0]
        dir_name = os.path.dirname(file_name)
        priority = conf["priority"][0]
        listener_arn = conf["listener_arn"][0]

        seen = self.encountered_priorities.setdefault(dir_name, {}).setdefault(listener_arn, {})
        owner = seen.setdefault(priority, self.entity_path)

        # Checkov evaluates a resource again when a run scans more than one
        # directory that reaches it, and that mustn't count as a clash.
        if owner != self.entity_path:
            self.details.append(f"Priority value {priority} is not unique for {listener_arn} in {dir_name}")
            self.details.append(f"Previously seen values are: {list(seen)}")
            return CheckResult.FAILED

        return CheckResult.PASSED


check = CKV2_FORMS_AWS_8()
