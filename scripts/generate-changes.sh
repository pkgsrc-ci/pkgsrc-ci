#!/usr/bin/env bash
#

set -x

if [ -n "${GIT_COMMIT}" -a -n "${GIT_PREVIOUS_COMMIT}" ]; then
	start=${GIT_PREVIOUS_COMMIT}
	end=${GIT_COMMIT}
else
	echo "Could not determine start and end commits, aborting."
	exit 1
fi

git log --name-status --pretty=format:'%H %an' ${start}..${end} \
    | awk -f $(dirname $0)/calculate-changes.awk
