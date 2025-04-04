#!/usr/bin/env bash
#

if [ -n "${GIT_LOG_START}" -a -n "${GIT_LOG_END}" ]; then
	start=${GIT_LOG_START}
	end=${GIT_LOG_END}
elif [ -n "${GIT_COMMIT}" -a -n "${GIT_PREVIOUS_COMMIT}" ]; then
	start=${GIT_PREVIOUS_COMMIT}
	end=${GIT_COMMIT}
else
	echo "Could not determine start and end commits, aborting."
	exit 1
fi

git log --name-status --pretty=format:'%H %an' ${start}..${end} \
    | awk -f $(dirname $0)/calculate-changes.awk
