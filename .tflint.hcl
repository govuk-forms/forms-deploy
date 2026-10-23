plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_unused_declarations" {
  # disabled because we use a shared "inputs.tf" file and a set of ".tfvars" filesin a lot of places
  # and tflint is unable to tell the difference between a variable being unused in a particular root
  # and a variable being completely unused.
  #
  # If asked to fix the problem, tflint will simply delete all the variables it thinks aren't used,
  # which results in half the variables being deleted erronously.
  enabled = false
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "mixed_snake_case" # we allow upper and lower case letters in our snakes

  variable {
    custom = "[a-zA-Z0-9-]+" # for now we're ok with our variables being kebab case
  }
}
