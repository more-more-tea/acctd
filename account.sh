#!/bin/bash
# set -x

function usage {
    echo $*
}

echo -n "Have you accounted today?(y/N): "
read ACC
# capitalize user input
echo $ACC | tr '[:lower:]' '[:upper:]'

if [ -z "$ACC" -o "$ACC" = "N" ]; then
    acctd
fi

echo "Good night!"
