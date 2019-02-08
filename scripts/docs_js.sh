#! /bin/bash

function shell_session_update {
    local X
}

ORIGINALCWD=$(pwd)
while test ! -f $CFGFILE ; do
    OLDCWD=$(pwd)
    cd ..
    if test "x$(pwd)" = "x$OLDCWD" ; then
	echo "$ORIGINALCWD does not seem to be in a fl-framework distribution"
	exit 1
    fi
done

# use the local Gulp
GULP="./node_modules/.bin/gulp"

CONF="doc/dgeni/conf.js"
JSDOCS=$(cat $CONF | sed -n /JSDOCS/p | sed -n /const/p | sed -E "s/.*\'(.*)\';/\1/")

if test "x$JSDOCS" = "x" ; then
    echo "sorry, cannot figure out where documentation is generated"
    exit 1
else
    echo "generating documentation in $JSDOCS"
    rm -rf $JSDOCS
    $GULP
    exit $?
fi
