#!/usr/bin/env bash
#
# Do everything required after this repository has been checked out.  There
# should be:
#
#	${WORKSPACE}/pkgsrc	Checkout of the pkgsrc we will use
#	${WORKSPACE}/pkgsrc-ci	Checkout of this repository
#
# This script assumes running as the 'ci' user.
#

set -eux

case "$(uname -s)" in
Linux|NetBSD)
	PATH=/usr/pkg/sbin:/usr/pkg/bin:/sbin:/bin:/usr/sbin:/usr/bin
	;;
SunOS)
	PATH=/opt/local/sbin:/opt/local/bin:/sbin:/usr/sbin:/usr/bin
	;;
esac

# Start with clean temporary directory.
rm -rf ${WORKSPACE_TMP}
mkdir -p ${WORKSPACE_TMP}

#
# Configure pbulk work area.  Some files are kept (e.g. bootstrap), while
# others are always removed.  Allow a full clean if requested.
#
if [ -n "${CLEAN_PBULK_DIR}" ]; then
	rm -rf ${HOME}/pbulk
fi
mkdir -p ${HOME}/pbulk
rm -rf ${HOME}/pbulk/{bulklog,distfiles,pkg,work}
mkdir -p ${HOME}/pbulk/{bulklog,distfiles,packages,work}

#
# Generate changes.  If there were none that are of interest then we're done.
#
cd ${WORKSPACE}/pkgsrc
${WORKSPACE}/pkgsrc-ci/scripts/generate-changes.sh \
    | tee ${WORKSPACE_TMP}/changes.txt
if [ ! -s ${WORKSPACE_TMP}/changes.txt ]; then
	echo "No changes to build."
	exit 0
fi

#
# Generate limited_list input file.
#
awk '{print $1}' ${WORKSPACE_TMP}/changes.txt \
    | sort | uniq >${HOME}/pbulk/limited_list

#
# Configure target mk.conf and pbulk.conf.  The system pbulk.conf must be
# modified to source this file.  Always write these files to simplify changes.
#
cat >${HOME}/pbulk/mk-include.conf <<-EOF
ALLOW_VULNERABLE_PACKAGES=	yes
CHECK_SSP=			no
DISTDIR=			${HOME}/pbulk/distfiles
FAILOVER_FETCH=			yes
MAKE_JOBS=			4
NO_PKGTOOLS_REQD_CHECK=		yes
PKG_DEVELOPER=			yes
SKIP_LICENSE_CHECK=		yes
USE_INDIRECT_DEPENDS=		yes
WRKOBJDIR=			${HOME}/pbulk/work
X11_TYPE=			modular
EOF

cat >${HOME}/pbulk/pbulk-include.conf <<EOF
master_mode=no
pkg_rsync_args=
pkg_rsync_target=
mail=:
bootstrapkit=${HOME}/pbulk/bootstrap.tar.gz
limited_list=${HOME}/pbulk/limited_list
unprivileged_user=${USER}
bulklog=${HOME}/pbulk/bulklog
packages=${HOME}/pbulk/packages
prefix=${HOME}/pbulk/pkg
pkgsrc=${WORKSPACE}/pkgsrc
pkgdb=${HOME}/pbulk/pkg/pkgdb
varbase=${HOME}/pbulk/pkg/var
# These variables are set by expanding variables, so need to be reset.
make=${HOME}/pbulk/pkg/bin/bmake
loc=${HOME}/pbulk/bulklog/meta
EOF

# Bootstrap if we haven't already.
if [ ! -f ${HOME}/pbulk/bootstrap.tar.gz ]; then
	cd ${WORKSPACE}/pkgsrc/bootstrap
	./bootstrap \
	    --gzip-binary-kit=${HOME}/pbulk/bootstrap.tar.gz \
	    --make-jobs=4 \
	    --mk-fragment=${HOME}/pbulk/mk-include.conf \
	    --prefix=${HOME}/pbulk/pkg \
	    --unprivileged \
	    --workdir=${HOME}/pbulk/bs.work
	rm -rf ${HOME}/pbulk/bs.work
fi

#
# Run bulkbuild.
#
bulkbuild

#
# Get list of failed packages.  If empty then we're done.
#
#PKGNAME=checkperms-1.12
#PKG_LOCATION=sysutils/checkperms

awk -F'|' '$2 ~ /^failed/ {print $1}' ${HOME}/pbulk/bulklog/meta/pbuild \
    > ${WORKSPACE_TMP}/failed_pkg.txt
if [ ! -s ${WORKSPACE_TMP}/failed_pkg.txt ]; then
	exit 0
fi

#
# Convert PKGNAME to PKGPATH to find if it was triggered by this build, and
# if so who is responsible.
#
awk -F= '
$1 ~ /^PKGNAME$/ {pkg=$2}
$1 ~ /^PKG_LOCATION$/ {print pkg " " $2}
' < ${HOME}/pbulk/bulklog/meta/presolve > ${WORKSPACE_TMP}/pkg_to_path.txt

while read pkg; do
	awk '/^'${pkg}'/ {print $2}' ${WORKSPACE_TMP}/pkg_to_path.txt
done < ${WORKSPACE_TMP}/failed_pkg.txt > ${WORKSPACE_TMP}/failed_pkgpath.txt

recip="jperkin@pkgsrc.org"

cat >${WORKSPACE_TMP}/failures.txt <<EOF
The following changes have been identified as causing a regression:

EOF
while read pkgpath; do
	grep ^${pkgpath} ${WORKSPACE_TMP}/changes.txt
done < ${WORKSPACE_TMP}/failed_pkgpath.txt \
	| while read pkgpath committer sha; do
		recip="${recip},${committer}@pkgsrc.org"
		echo "${pkgpath}  <${committer}>  https://github.com/NetBSD/pkgsrc/commit/${sha}" >>${WORKSPACE_TMP}/failures.txt
	done
echo "" >>${WORKSPACE_TMP}/failures.txt

cat ${WORKSPACE_TMP}/failures.txt ${HOME}/pbulk/meta/report.txt | /usr/sbin/sendmail -oi -rjperkin@pkgsrc.org -t <<EOF
From: jperkin@pkgsrc.org
To: jperkin@pkgsrc.org
Subject: bulk build report

Would email ${recip}

EOF
