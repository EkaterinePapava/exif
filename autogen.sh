#!/bin/sh
# autogen.sh - initialize and clean automake&co based build trees
#
# For more detailed info, run "autogen.sh --help" or scroll down to the
# print_help() function.


if test "$(pwd)" != "`pwd`"
then
	echo "Urgh. Dinosaur shell, eh?"
	exit 1
fi


########################################################################
# Constant and initial values

debug=false
self="$(basename "$0")"
autogen_version="0.3.0"


########################################################################
# Print help message

print_help() {
    cat<<EOF
$self - initialize automake/autoconf/gettext/libtool based build system

Usage:
    $self [<command>...] [<directory>...]

Runs given command sequence on all given directories, in sequence.
If there is no command given, --init is assumed.
If there is no directory given, the location of $self is assumed.

Commands:
    --help
        Print this help text
    --version
        Print the tool versions
    --verbose
        Verbose output

    --clean
        Clean all files and directories generated by "$self --init"
    --init
        Converts untouched CVS checkout into a build tree which
        can be processed further by running the classic
          ./configure && make && make install

$self depends on automake, autoconf, libtool and gettext.

You may want to set AUTOCONF, AUTOHEADER, AUTOMAKE, ACLOCAL,
AUTOPOINT, LIBTOOLIZE to use specific version of these tools, and
AUTORECONF_OPTS to add options to the call to autoreconf.
EOF
}


########################################################################
# Print software versions

print_versions() {
    echo "${self} (ndim's autogen) ${autogen_version}"
    for tool in \
	"${AUTOCONF-autoconf}" \
	"${AUTOMAKE-automake}" \
	"${AUTOPOINT-autopoint}" \
	"${LIBTOOLIZE-libtoolize}"
    do
    	"$tool" --version 2>&1 | sed '1q'
    done
}


########################################################################
# Initialize variables for configure.{in,ac} in $1

init_vars() {
    dir="$1"
    echo -n "Looking for \`${dir}/configure.{ac,in}'..."
    # There are shells which don't understand {,} wildcards
    CONFIGURE_AC=""
    for tmp in "${dir}/configure.ac" "${dir}/configure.in"; do
	if test -f "$tmp"; then
	    CONFIGURE_AC="$tmp"
	    echo " $tmp"
	    break
	fi
    done
    if test "x$CONFIGURE_AC" = "x"; then
	echo " no."
	exit 1
    fi

    if "$debug"; then
	if test "$(uname -o)" = "Cygwin"; then
	    # Cygwin autoreconf doesn't understand -Wall
	    AUTORECONF_OPTS="$AUTORECONF_OPTS --verbose"
	else
	    AUTORECONF_OPTS="$AUTORECONF_OPTS --verbose -Wall"
	fi
    fi

    echo -n "Initializing variables for \`${dir}'..."
    # FIXME: Just getting those directories and cleaning them isn't enough.
    #        OK, the "init" part is done recursively by autopoint, so that is easy.
    #        But the cleaning should also work recursively, but that is difficult
    #        with the current structure of the script.
    AG_SUBDIRS="$(for k in $(sed -n 's/^[[:space:]]*AC_CONFIG_SUBDIRS(\[\{0,1\}\([^])]*\).*/\1/p' "$CONFIGURE_AC"); do echo "${dir}/${k}"; done)"
    AG_AUX="$(sed -n 's/^AC_CONFIG_AUX_DIR(\[\{0,1\}\([^])]*\).*/\1/p' < "$CONFIGURE_AC")"
    if test "x$AG_AUX" = "x"; then
	AG_AUX="."
    fi
    AG_CONFIG_H="$(sed -n 's/^\(A[CM]_CONFIG_HEADERS\?\)(\[\{0,1\}\([^]),]*\).*/\2/p' < "$CONFIGURE_AC")"
    AG_CONFIG_K="$(sed -n 's/^\(A[CM]_CONFIG_HEADERS\?\)(\[\{0,1\}\([^]),]*\).*/\1/p' < "$CONFIGURE_AC")"
    if echo "x$AG_CONFIG_H" | grep -q ':'; then
	echo "$AG_CONFIG_K contains unsupported \`:' character: \`$AG_CONFIG_H'"
	exit 13
    fi
    if test "x$AG_CONFIG_H" != "x"; then
	AG_CONFIG_DIR="$(dirname "${AG_CONFIG_H}")"
	AG_GEN_CONFIG_H="${AG_CONFIG_H} ${AG_CONFIG_H}.in ${AG_CONFIG_DIR}/stamp-h1 ${AG_CONFIG_DIR}/stamp-h2"
    else
	AG_CONFIG_DIR=""
	AG_GEN_CONFIG_H=""
    fi
    for d in "$AG_AUX" "$AG_CONFIG_DIR"; do
	if test -n "$d" && test ! -d "$d"; then
	    mkdir "$d"
	fi
    done
    AG_GEN_ACAM="aclocal.m4 configure $AG_AUX/config.guess $AG_AUX/config.sub $AG_AUX/compile"
    AG_GEN_RECONF="$AG_AUX/install-sh $AG_AUX/missing $AG_AUX/depcomp"
    AG_GEN_GETTEXT="$AG_AUX/mkinstalldirs $AG_AUX/config.rpath ABOUT-NLS"
    while read file; do
	AG_GEN_GETTEXT="${AG_GEN_GETTEXT} ${file}"
    done <<EOF
m4/codeset.m4
m4/gettext.m4
m4/glibc21.m4
m4/iconv.m4
m4/intdiv0.m4
m4/intmax.m4
m4/inttypes-pri.m4
m4/inttypes.m4
m4/inttypes_h.m4
m4/isc-posix.m4
m4/lcmessage.m4
m4/lib-ld.m4
m4/lib-link.m4
m4/lib-prefix.m4
m4/longdouble.m4
m4/longlong.m4
m4/nls.m4
m4/po.m4
m4/printf-posix.m4
m4/progtest.m4
m4/signed.m4
m4/size_max.m4
m4/stdint_h.m4
m4/uintmax_t.m4
m4/ulonglong.m4
m4/wchar_t.m4
m4/wint_t.m4
m4/xsize.m4
po/Makefile.in.in
po/Makevars.template
po/Rules-quot
po/boldquot.sed
po/en@boldquot.header
po/en@quot.header
po/insert-header.sin
po/quot.sed
po/remove-potcdate.sin
po/stamp-po
EOF
    AG_GEN_CONF="config.status config.log"
    AG_GEN_LIBTOOL="$AG_AUX/ltmain.sh libtool"
    AG_GEN_FILES="$AG_GEN_ACAM $AG_GEN_RECONF $AG_GEN_GETTEXT"
    AG_GEN_FILES="$AG_GEN_FILES $AG_GEN_CONFIG_H $AG_GEN_CONF $AG_GEN_LIBTOOL"
    AG_GEN_DIRS="autom4te.cache"
    echo " done."

    if "$debug"; then set | grep '^AG_'; fi
}


########################################################################
# Clean generated files from $* directories

clean() {
    if test "x$AG_GEN_FILES" = "x"; then echo "Internal error"; exit 2; fi
    dir="$1"
    while test "$dir"; do
	echo "$self:clean: Entering directory \`${dir}'"
	(
	    if cd "$dir"; then
		echo -n "Cleaning autogen generated files..."
		rm -rf ${AG_GEN_DIRS}
		rm -f ${AG_GEN_FILES}
		echo " done."
		if test -h INSTALL; then rm -f INSTAL; fi
		echo -n "Cleaning generated Makefile, Makefile.in files..."
		if "$debug"; then echo; fi
		find . -type f -name 'Makefile.am' -print | \
		    while read file; do
		    echo "$file" | grep -q '/{arch}' && continue
		    echo "$file" | grep -q '/\.svn'  && continue
		    echo "$file" | grep -q '/CVS'    && continue
		    base="$(dirname "$file")/$(basename "$file" .am)"
		    if "$debug"; then
			echo -e "  Removing files created from ${file}"
		    fi
		    rm -f "${base}" "${base}.in"
		done
		if "$debug"; then :; else echo " done."; fi
		echo -n "Removing *~ backup files..."
		find . -type f -name '*~' -exec rm -f {} \;
		echo " done."
	    fi
	)
	echo "$self:clean: Left directory \`${dir}'"
	shift
	dir="$1"
    done
}


########################################################################
# Initialize build system in $1 directory

init() {
    dir="$1"
    if test "x$AG_GEN_FILES" = "x"; then echo "Internal error"; exit 2; fi
    echo "$self:init: Entering directory \`${dir}'"
(
if cd "${dir}"; then
    echo "Running <<" autoreconf --install --symlink ${AUTORECONF_OPTS} ">>"
    if autoreconf --install --symlink ${AUTORECONF_OPTS}; then
	:; else
	status="$?"
	echo "autoreconf quit with exit code $status, aborting."
	exit "$status"
    fi    
    echo "You may run ./configure now in \`${dir}'."
    echo "Run as \"./configure --help\" to find out about config options."
else
    exit "$?"
fi
)
    # Just error propagation
    status="$?"
    echo "$self:init: Left directory \`${dir}'"
    if test "$status" -ne "0"; then
	exit "$status"
    fi
}


########################################################################
# Parse command line.
# This still accepts more than the help text says it does, but that
# isn't supported.

commands="init" # default command in case none is given
pcommands=""
dirs="$(dirname "$0")"
#dirs="$(cd "$dirs" && pwd)"
pdirs=""
# Yes, unquoted $@ isn't space safe, but it works with simple shells.
for param in $@; do
    case "$param" in
	--clean)
	    pcommands="$pcommands clean"
	    ;;
	--init)
	    pcommands="$pcommands init"
	    ;;
	--verbose)
	    debug="true"
	    ;;
	--version)
	    print_versions
	    exit 0
	    ;;
	-h|--help)
	    print_help
	    exit 0
	    ;;
	-*)
	    echo "Unhandled $self option: $param"
	    exit 1
	    ;;
	*)
	    pdirs="${pdirs} ${param}"
	    ;;
    esac
done
if test "x$pcommands" != "x"; then
    # commands given on command line? use them!
    commands="$pcommands"
fi
if test "x$pdirs" != "x"; then
    # dirs given on command line? use them!
    dirs="$pdirs"
fi


########################################################################
# Actually run the commands

for dir in ${dirs}; do
    echo "Running commands on directory \`${dir}'"
    if test ! -d "$dir"; then
	echo "Could not find directory \`${dir}'"	
    fi
    init_vars "$dir"
    for command in ${commands}; do
	"$command" "$dir" ${AG_SUBDIRS}
    done
done

exit 0

# Please do not remove this:
# filetype: 89b1e88e-4cf2-44f1-980d-730067367775
# I use this to find all the different instances of this file which 
# are supposed to be synchronized.
