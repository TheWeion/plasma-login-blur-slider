#!/bin/bash
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# lock-screen-session.sh <greeter binary> <log file>
#
# Runs inside headless-session.sh, as an ordinary user: starts the lock screen
# in its test mode (a window instead of a locked session) and waits until the
# add-on has reported in, or two minutes at most.

set -u
greeter=$1
log=$2

"$greeter" --testing > "$log" 2>&1 &
pid=$!

for _ in $(seq 1 240); do
    grep -q "wallpaper blur set to" "$log" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.5
done
sleep 3

if kill -0 "$pid" 2>/dev/null; then
    echo "plbs-test: lock screen still running" >> "$log"
else
    echo "plbs-test: lock screen exited" >> "$log"
fi
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
exit 0
