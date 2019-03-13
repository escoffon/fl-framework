#! /usr/bin/env bash

RARGS=""

for A in "$@" ; do
    RARGS="$RARGS ${A/test\/FlFrameworkTestApp\//}"
done

echo "running in the test app directory (test/FlFrameworkTestApp)"
cd test/FlFrameworkTestApp

echo "running test command: bash $0 $RARGS"
bash $0 $RARGS
