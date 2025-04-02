#!/usr/bin/env bash
#

if [ -n "${GIT_COMMIT}" -a -n "${GIT_PREVIOUS_COMMIT}" ]; then
	start=${GIT_PREVIOUS_COMMIT}
	end=${GIT_COMMIT}
fi

git log --name-status --pretty=format:'%H %an' \
    | awk -f $(dirname $0)/calculate-changes.awk
