#!/bin/sh

################################################################################
#
# performance-checker.sh
# POST to http://golf.shinh.org/checker.rb with program source and input file.
#
# first commit.
#
# written by Tpaefawzen on 2022-07-03
#
################################################################################

################################################################################
#
# Copyright 2022 Tpaefawzen
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
#
################################################################################

# initializer
set -eu
umask 0022
export LC_ALL=C
type command >/dev/null 2>&1 &&
type getconf >/dev/null 2>&1 &&
export PATH="$(command -p getconf PATH)${PATH+:}${PATH-:}"
export UNIX_STD=2003
export POSIXLY_CORRECT=1

case "$0" in (*/*)
	export SRC_DIR="${0%/*}"
;;(*)
	# no slashes; invoking from somewhere on ${PATH}?
	export SRC_DIR="$(which "$0")"
esac

# let me think of utilities
export PATH="$SRC_DIR/shutils:$PATH"

# hi utility
error_exit(){
	echo "${0##*/}: $2" 1>&2
	exit "$1"
}
type which >/dev/null 2>&1 || {
  which(){
	command -v "$1" 2>/dev/null | grep '^/' || {		
		echo 'which: not found' 1>&2 &&
		(exit 1)
  }
}

# wget or curl?
case "${FORCE_WGET:-}" in (?*)
	CMD_WGET="$(which wget)"
esac

case "${FORCE_CURL:-}" in (?*)
	CMD_CURL="$(which curl)"
esac

case "${CMD_WGET:-}${CMD_CURL:-}" in ('')
	if type wget >/dev/null 2>&1; then
		CMD_WGET="$(which wget)"
	elif type curl >/dev/null 2>&1; then
		CMD_CURL="$(which curl)"
	else
		error_exit 1 "wget or curl required"
	fi
esac

usage(){
	cat <<-USAGE 1>&2
	Usage: [env [FORCE_WGET=1|FORCE_CURL=1]] ${0##*/} SOURCE_PATH [INPUT_PATH]
	USAGE
	exit $1
}

# parse options!
case "$#" in (1|2)
	:
;;(*)
	usage 1
esac

# main!
exit_trap() {
  set -- ${1:-} $?  # $? is set as $1 if no argument given
  trap '' EXIT HUP INT QUIT PIPE ALRM TERM
  [ -d "${Tmp:-}" ] && rm -rf "${Tmp%/*}/_${Tmp##*/_}"
  trap -  EXIT HUP INT QUIT PIPE ALRM TERM
  exit $1
}
trap 'exit_trap' EXIT HUP INT QUIT PIPE ALRM TERM
Tmp=`mktemp -d -t "_${0##*/}.$$.XXXXXXXXXXX"` || error_exit 1 'Failed to mktemp'

URL=http://golf.shinh.org/checker.rb

s="$(mime-make -m)"
content_type='Content-type: multipart/form-data; boundary="'$s'"'

mime-make -b "$s" -F file "$1" ${2:+-F input "$2"} |
if test "${CMD_WGET:-}"; then
	cat >"$Tmp/mimedata"
	"$CMD_WGET" -q -O - \
		--header="$content_type" \
		--post-file="$Tmp/mimedata" \
		"$URL"
elif test "${CMD_CURL:-}"; then
	"$CMD_CURL" -s \
		-H "$content_type" \
		--data-binary @- \
		"$URL"
fi

exit_trap 0
