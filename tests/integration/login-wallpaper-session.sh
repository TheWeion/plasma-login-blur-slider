#!/bin/bash
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# login-wallpaper-session.sh <log file>
#
# Runs inside headless-session.sh, as the login user: starts Plasma Login
# Manager's wallpaper process the way the login screen does, asks it to blur
# (as the greeter does when the password prompt appears) and to unblur again,
# and notes whether it survived.

set -u
log=$1

plasma-login-wallpaper > "$log" 2>&1 &
pid=$!

for _ in $(seq 1 120); do
    busctl --user status org.kde.plasma.wallpaper >/dev/null 2>&1 && break
    sleep 0.5
done
sleep 2

busctl --user call org.kde.plasma.wallpaper /Wallpaper org.kde.plasma.wallpaper blurScreen s HEADLESS-1 >/dev/null 2>&1
sleep 5
busctl --user call org.kde.plasma.wallpaper /Wallpaper org.kde.plasma.wallpaper blurScreen s "" >/dev/null 2>&1
sleep 3

if kill -0 "$pid" 2>/dev/null; then
    echo "plbs-test: wallpaper process still running" >> "$log"
else
    echo "plbs-test: wallpaper process exited" >> "$log"
fi
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
exit 0
