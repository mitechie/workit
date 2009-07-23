#!/bin/zsh

#
# Process functions to start/stop things as part of postactivate/deactivate
# commands. Each start should have a stop set
#

# MySQL

# check if mysqld is in the process list
# see if it is started or not
MYSQL_STOP="sudo /etc/init.d/mysql stop > /dev/null"
MYSQL_START="sudo /etc/init.d/mysql start > /dev/null"

function zprocess_running() {
    # $1 should be the process we want to look for
    o=$(ps cax | grep -c "$1\$")
    if [ $o -gt 0 ]; then
        started=1
    else
        started=0
    fi

    return started
}

function zmysql_stop () {
    zprocess_running 'mysqld'
    started="$?"

    if [ $started -eq 1 ]; then
        eval "$MYSQL_STOP"
    else
        echo "MySql Not Running"
        return 1
    fi
    
    # make sure that it's stopped
    zprocess_running 'mysqld'
    started="$?"
    if [ $started -eq 1 ]; then
        echo "Could not stop MySql"
        return 0
    fi

    return 1
}

# PgSQL

# ctags


