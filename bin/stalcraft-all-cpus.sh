#!/bin/bash

while true; do
    pid=$(pgrep -n -f 'stalzone\.exe')

    if [ -n "$pid" ]; then
        taskset -cp 0-11 "$pid" >/dev/null 2>&1
    fi

    sleep 1
done
