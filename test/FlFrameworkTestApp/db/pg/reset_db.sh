#! /bin/bash

function shell_session_update {
    local X
}

DEFAULT_ENV="development"

if test "x$1" = "x" ; then
    echo "using default environment ${DEFAULT_ENV}"
    TARGET_ENV=$DEFAULT_ENV
else
    TARGET_ENV=$1
fi

TARGET_DB="fltestapp_${TARGET_ENV}"

R="${TARGET_DB}_r.sql"

echo "DROP DATABASE IF EXISTS ${TARGET_DB};" >${R}
echo "CREATE DATABASE ${TARGET_DB};" >>${R}
echo "GRANT ALL PRIVILEGES ON DATABASE ${TARGET_DB} TO fltestapp;" >>${R}

echo "resetting database $TARGET_DB:"
cat ${R}
psql -f ${R}
XCODE=$?
rm ${R}

exit $XCODE
