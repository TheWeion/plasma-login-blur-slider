#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# headless-session.sh <command>...
#
# Starts a headless Wayland compositor (sway, drawing in software, one
# 1280x720 output called HEADLESS-1), runs the command as a client of it and
# stops the compositor again. Meant to be started through dbus-run-session, as
# the user the command should run as. No display, GPU or seat is needed.

set -u

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/plbs-test-runtime-$(id -u)}
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
# Sockets of an earlier compositor would be picked up instead of ours.
rm -f "$XDG_RUNTIME_DIR"/wayland-* "$XDG_RUNTIME_DIR"/sway-ipc.*

export LIBGL_ALWAYS_SOFTWARE=1
export QT_FORCE_STDERR_LOGGING=1

config=$XDG_RUNTIME_DIR/sway-headless.conf
: > "$config"

WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    sway -c "$config" > "$XDG_RUNTIME_DIR/sway.log" 2>&1 &
compositor=$!

socket=""
for _ in $(seq 1 120); do
    for candidate in "$XDG_RUNTIME_DIR"/wayland-?; do
        if [ -S "$candidate" ]; then
            socket=$candidate
        fi
    done
    [ -n "$socket" ] && break
    sleep 0.5
done

if [ -z "$socket" ]; then
    echo "headless-session: the compositor did not start:" >&2
    cat "$XDG_RUNTIME_DIR/sway.log" >&2
    kill "$compositor" 2>/dev/null
    exit 1
fi

export WAYLAND_DISPLAY=${socket##*/}
export QT_QPA_PLATFORM=wayland

"$@"
status=$?

kill "$compositor" 2>/dev/null
wait "$compositor" 2>/dev/null
exit "$status"
