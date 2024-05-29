PAGER=cat

repo-context-setup: repo-context-set-vars repo-context-set-secrets

repo-context-cleanup: repo-cleanup-vars repo-cleanup-secrets

repo-context-cleanup-vars:
	gh variable list --json name --jq '.[].name' \
	| xargs -n1 echo gh variable delete

repo-context-cleanup-secrets:
	gh secret list --json name --jq '.[].name' \
	| xargs -n1 echo gh secret delete

repo-context-set-vars:
	gh variable list
	gh variable set -f .env
	gh variable list

repo-context-set-secrets:
	gh secret list
	gh secret set  -f .secrets
	gh secret list

run:
	find . -name '.git' -prune -o -type f -print | entr -c \
		act \
			--actor 			"${GITHUB_USER}" \
			--secret 		  GITHUB_TOKEN="${GITHUB_TOKEN}" \
			--secret-file .secrets \
			--var-file    .env \
			--workflows   .github/workflows/test.yml \
			--job test \
			--rm

build-image:
		act \
			--actor 			"${GITHUB_USER}" \
			--secret 		  GITHUB_TOKEN="${GITHUB_TOKEN}" \
			--secret-file .secrets \
			--var-file    .env \
			--workflows   .github/workflows/build-image.yml
