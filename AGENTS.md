# Agent instructions

## Commits

- Split features into well-scoped commits. Each commit should leave the tests
  green.
- Commit titles: 50 characters or fewer, imperative, naming only the thing
  changed ("Add Brand model", not "Add Brand model backed by database table").
- Commit bodies: explain why the change is needed, and include only context
  the diff doesn't show, such as external constraints or why an approach was
  forced.
- Fold additional changes into the commit they belong to rather than adding
  fixup commits.
- Don't push or update pull requests unless asked. Committing locally is fine.

## Pull requests

- Use `.github/pull_request_template.md`.
- Keep descriptions to a few short paragraphs, with only context a reviewer
  can't see in the diff.
- Don't mention AI tooling in pull request descriptions.
- Don't describe fixes as security or vulnerability issues in public pull
  requests. Describe what the code now enforces.
