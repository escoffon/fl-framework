#! /usr/bin/env bash

RARGS=""

for A in "$@" ; do
    RARGS="$RARGS ${A/spec\/testapp\//}"
done

echo "running in the testapp directory (spec/testapp)"
cd spec/testapp

echo "running test command: bash $0 $RARGS"
bash $0 $RARGS
