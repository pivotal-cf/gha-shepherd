# GitHub Action for managing shepherd leases

# Usage
This action abstracts claiming and unclaiming shepherd leases.

[.github/workflows/test.yml](.github/workflows/test.yml) provides a good starting point.

# Development
1. Open with VisualStudion Code
   - Check if [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension is installed.
1. Edit [.secrets](.secrets) file add real API token.
   - Create new token `shepherd create service-account gha-shepherd`
   - Local workflow dev runner [act](https://github.com/nektos/act) injects content of [.env](.env) and [.secrets](.secrets) into workflow execution context.
1. Open project inside the dev container.
1. Run `make run` to start.

# Deployment
1. To upload variables and secrets to the default remote repo for the current branch. **PROCEED WITH CARE** use `make repo-context-setup`. This will overwrite remote vaules with local from [.env](.env) and [.secrets](.secrets)
