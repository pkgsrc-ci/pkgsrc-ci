#
# Parse the output of 'git log' and group changes by commit sha, committer, and
# files modified.  Ignore any non-package changes.
#
# The input is expected to be of the format generate by:
#
#   $ git log --name-status --pretty=format:'%H %an' <sha1>..<sha2>
#
# The output will be one line per package directory per commit, so for example:
#
#   audio/qt6-qtspeech adam 90332e1df3936abe8b623fe951e4c1998a7aea15
#   x11/qt6-qtserialport adam 90332e1df3936abe8b623fe951e4c1998a7aea15
#   lang/rust ryoon 4abcdaad97a71032f8ce3182a7a9b001299849dd
#
# Known issues:
#
#   * Does not currently ignore changes to include-only directories, for
#     example lang/php, which are not packages and will fail pbulk scan.
#
#   * Should probably ignore meta-pkgs changes to avoid excessive build
#     turnaround times that should be deferred to full bulk build runs.
#

function print_change() {
	for (dir in pkgdirs) {
		print dir " " committer " " sha
	}
	committer = ""
	sha = ""
	delete pkgdirs
}

BEGIN {
	# Ignore any changes to these top-level directories.
	split("bootstrap,doc,licenses,mk,regress", ignore_dirs, ",");
}

#
# "<commit sha> <committer>"
#
/^[0-9a-f]{40}/ {
	sha = $1
	committer = $2
}

#
# "M       audio/libsoxr/Makefile"
#
/^[A-Z]/ {
	n = split($2, arr, "/");
	if (n > 2) {
		if (arr[1] in ignore_dirs)
			next;
		dir = arr[1] "/" arr[2];
		if (!(dir in pkgdirs)) {
			pkgdirs[dir] = dir
		}
	}
}

#
# Changes are delimited by empty lines.  The last change does not have a
# trailing empty line so also print at the end.
#
/^$/ {
	print_change()
}
END {
	print_change()
}
