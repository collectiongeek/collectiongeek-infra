# Partial backend config — concrete values are supplied at `tofu init` time so
# they don't sit in this public repo.
#   - In CI: the workflow writes a backend.hcl from GitHub Environment vars and
#     runs `tofu init -backend-config=backend.hcl`.
#   - On a laptop: drop a local-only `backend.hcl` next to this file and run
#     `tofu init -backend-config=backend.hcl`. The file is gitignored.
terraform {
  backend "s3" {
    encrypt = true
  }
}
