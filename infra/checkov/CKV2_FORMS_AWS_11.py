from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.provider.base_check import BaseProviderCheck


class CKV2_FORMS_AWS_11(BaseProviderCheck):
    def __init__(self):
        super().__init__(
            name="Check that AWS providers set default_tags",
            id="CKV2_FORMS_AWS_11",
            categories=[CheckCategories.CONVENTION],
            supported_provider=["aws"],
        )

    def scan_provider_conf(self, conf):
        # Parsed blocks are wrapped in lists: an empty block is [[]] or [{}],
        # and `tags = {}` or `tags = null` is {"tags": [{}]} or {"tags": [None]}.
        # An expression Checkov can't resolve stays a non-empty string, so it passes.
        default_tags = conf.get("default_tags")
        if not default_tags or not isinstance(default_tags[0], dict):
            return CheckResult.FAILED
        tags = default_tags[0].get("tags")
        if isinstance(tags, list):
            tags = tags[0] if tags else None
        if tags:
            return CheckResult.PASSED
        return CheckResult.FAILED


check = CKV2_FORMS_AWS_11()
