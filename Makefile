PAGER=cat
GH_ARGS="--repo cloudfoundry/bosh-package-cf-cli-release"

repo-context-setup: repo-context-set-vars repo-context-set-secrets

repo-context-cleanup: repo-cleanup-vars repo-cleanup-secrets

repo-context-cleanup-vars:
	gh variable ${GH_ARGS} list --json name --jq '.[].name' \
	| xargs -n1 echo gh variable ${GH_ARGS} delete

repo-context-cleanup-secrets:
	gh secret ${GH_ARGS} list --json name --jq '.[].name' \
	| xargs -n1 echo gh secret ${GH_ARGS} delete

repo-context-set-vars:
	gh variable ${GH_ARGS} list
	gh variable ${GH_ARGS} set -f .env
	gh variable ${GH_ARGS} list

repo-context-set-secrets:
	gh secret ${GH_ARGS} list
	gh secret ${GH_ARGS} set  -f .secrets
	gh secret ${GH_ARGS} list

run:
	find . -name '.git' -prune -o -type f -print | entr -c \
		act \
			--actor 			"${GITHUB_USER}" \
			--secret 		  GITHUB_TOKEN="${GITHUB_TOKEN}" \
			--secret-file .secrets \
			--var-file    .env \
			--workflows   .github/workflows/test.yml \
			--job test \
			--env ACTIONS_RUNNER_DEBUG=true \
			--env ACTIONS_RUNTIME_TOKEN=1234 \
			--artifact-server-path /tmp/artifact \
			--rm