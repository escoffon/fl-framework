#! /bin/bash

function shell_session_update {
    local X
}

ORIGINALCWD=$(pwd)

while test ! -d db/pg ; do
    OLDCWD=$(pwd)
    cd ..
    if test "x$(pwd)" = "x$OLDCWD" ; then
	echo "$ORIGINALCWD does not seem to be in a testapp distribution"
	exit 1
    fi
done

DEFAULT_ENV="development"

if test "x$1" = "x" ; then
    echo "usage: $0 environment [seed|noseed]"
    exit 1
else
    TARGET_ENV=$1
fi

if test "x$2" = "x" ; then
    SEED=noseed
else
    SEED=$2
fi

if bash db/pg/reset_db.sh $TARGET_ENV ; then
    echo "did reset the database for environment $TARGET_ENV"
else
    echo "failed to reset the database for environment $TARGET_ENV"
    exit 1
fi

export RAILS_ENV=$TARGET_ENV
if rake db:migrate ; then
    echo "did migrate the database for environment $TARGET_ENV"
else
    echo "failed to migrate the database for environment $TARGET_ENV"
    exit 1
fi

if test $SEED = "seed" ; then
    echo "seeding the database"
    bin/rails db:seed
fi

exit 0
