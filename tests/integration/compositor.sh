#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The login screen's compositor: third-party "blur every window" effects that
# are enabled for the login user get switched off there, by "sync" (as root)
# and by "login-compositor" (as the login user, which is what runs before the
# login screen's compositor starts), and "remove" puts back exactly what was
# switched off.
#
# Needs the package installed. Works on the real login user's kwinrc, on
# /etc/plasma-login-blur-slider.conf and on /etc/xdg/kwinrc, and restores all
# three.

# The conditions handed to check_that are evaluated there, not here: they are
# quoted on purpose, and the variables in them do get used.
# shellcheck disable=SC2016,SC2034

# shellcheck source=tests/integration/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
require_system_tests
need "$PROG" kreadconfig6 kwriteconfig6 runuser

LOGIN_USER=plasmalogin
login_home=$(getent passwd "$LOGIN_USER" | cut -d: -f6)
if [ -z "$login_home" ]; then
    echo "SKIP: no $LOGIN_USER user (Plasma Login Manager not installed?)"
    exit 0
fi

K=$login_home/.config/kwinrc
FIXTURE=$TESTS_DIR/fixtures/kwinrc-desktop-settings
TOOL_CONF=/etc/plasma-login-blur-slider.conf
SYSTEM_KWINRC=/etc/xdg/kwinrc

save=$(mktemp -d)
for file in "$K" "$TOOL_CONF" "$SYSTEM_KWINRC"; do
    if [ -e "$file" ]; then
        cp -p -- "$file" "$save/$(echo "$file" | tr / _)"
    fi
done

cleanup() {
    local file
    for file in "$K" "$TOOL_CONF" "$SYSTEM_KWINRC"; do
        if [ -e "$save/$(echo "$file" | tr / _)" ]; then
            cp -p -- "$save/$(echo "$file" | tr / _)" "$file"
        else
            rm -f -- "$file"
        fi
    done
    rm -rf -- "$save"
    # leave the add-on the way a fresh install has it
    "$PROG" sync --quiet >/dev/null 2>&1
}
trap cleanup EXIT

# Desktop settings, with Better Blur DX and the like enabled, as the login
# user's compositor settings; nothing configured for the tool.
reset() {
    install -d -o "$LOGIN_USER" -g "$LOGIN_USER" -m 755 "$login_home/.config"
    install -o "$LOGIN_USER" -g "$LOGIN_USER" -m 644 "$FIXTURE" "$K"
    rm -f -- "$TOOL_CONF" "$SYSTEM_KWINRC"
}

val() {
    kreadconfig6 --file "$K" --group Plugins --key "$1"
}

owner_and_mode() {
    stat -c '%U:%G %a' "$K"
}

as_login_user() {
    (cd / && runuser -u "$LOGIN_USER" -- env -i HOME="$login_home" PATH=/usr/bin "$@")
}

section "sync, as root, switches the effects off for the login user"
reset
"$PROG" remove --quiet >/dev/null 2>&1
out=$("$PROG" sync --quiet 2>&1)
echo "  output: $out"
check_that "better_blur_dx is off" '[ "$(val better_blur_dxEnabled)" = false ]'
check_that "forceblur is off" '[ "$(val forceblurEnabled)" = false ]'
check_that "KWin's own blur setting is untouched" '[ "$(val blurEnabled)" = false ]'
check_that "other effects are untouched" \
    '[ "$(val diminactiveEnabled)" = true ] && [ "$(val magiclampEnabled)" = true ]'
check_that "the file is still the login user's, mode 644" \
    '[ "$(owner_and_mode)" = "$LOGIN_USER:$LOGIN_USER 644" ]'
check_that "what was switched off is recorded" \
    '[ "$(kreadconfig6 --file "$K" --group plasma-login-blur-slider --key DisabledEffects)" = "better_blur_dx,forceblur" ]'
check_that "nothing else in the file changed" \
    '[ "$(diff "$FIXTURE" "$K" | grep -c "^[<>]")" = 7 ]'
check_that "it says so even with --quiet" \
    'echo "$out" | grep -q "switched off for the login screen"'

section "a second sync changes nothing"
before=$(stat -c %Y.%y "$K")
sleep 1.1
out=$("$PROG" sync --quiet 2>&1)
check_that "no output" '[ -z "$out" ]'
check_that "the file was not rewritten" '[ "$(stat -c %Y.%y "$K")" = "$before" ]'

section "status reports it"
check_that "as root" \
    '"$PROG" status | grep -q "Login compositor: .*switched off for the login screen: better_blur_dx forceblur"'
check_that "an ordinary user is told to ask root" \
    'runuser -u nobody -- "$PROG" status 2>&1 | grep -q "Login compositor: .*run this command as root"'

section "login-compositor, as the login user (what runs before the compositor starts)"
reset
out=$(as_login_user "$PROG" login-compositor --quiet 2>&1)
echo "  output: $out"
check_that "better_blur_dx is off" '[ "$(val better_blur_dxEnabled)" = false ]'
check_that "forceblur is off" '[ "$(val forceblurEnabled)" = false ]'
check_that "the file is still the login user's, mode 644" \
    '[ "$(owner_and_mode)" = "$LOGIN_USER:$LOGIN_USER 644" ]'
before=$(stat -c %Y.%y "$K")
sleep 1.1
as_login_user "$PROG" login-compositor --quiet
check_that "a second run leaves the file alone" '[ "$(stat -c %Y.%y "$K")" = "$before" ]'

section "desktop settings copied over again are put right at the next start"
reset
as_login_user "$PROG" login-compositor --quiet >/dev/null 2>&1
check_that "off again" '[ "$(val better_blur_dxEnabled)" = false ]'

section "opting out"
reset
echo 'LOGIN_COMPOSITOR_BLUR=keep' > "$TOOL_CONF"
out=$("$PROG" sync --quiet 2>&1)
check_that "the effects are left alone, silently" \
    '[ "$(val better_blur_dxEnabled)" = true ] && [ -z "$out" ]'
check_that "status says they were left alone" \
    '"$PROG" status | grep -q "enabled and left alone"'
echo 'LOGIN_COMPOSITOR_BLUR=maybe' > "$TOOL_CONF"
check_that "an invalid value is rejected with a message" \
    '"$PROG" status 2>&1 >/dev/null | grep -q "must be"'

section "remove puts back what was switched off, and nothing else"
reset
"$PROG" sync --quiet >/dev/null 2>&1
out=$("$PROG" remove 2>&1)
check_that "it says what it switched back on" \
    'echo "$out" | grep -q "switched back on: better_blur_dx forceblur"'
check_that "better_blur_dx is back on" '[ "$(val better_blur_dxEnabled)" = true ]'
check_that "forceblur is back on" '[ "$(val forceblurEnabled)" = true ]'
check_that "the record is gone" '! grep -q "plasma-login-blur-slider" "$K"'
check "the file is identical to the original again" cmp -s "$FIXTURE" "$K"
check_that "the file is still the login user's, mode 644" \
    '[ "$(owner_and_mode)" = "$LOGIN_USER:$LOGIN_USER 644" ]'
as_login_user "$PROG" login-compositor --quiet >/dev/null 2>&1
check_that "with the add-on removed, the pre-start step does nothing" \
    '[ "$(val better_blur_dxEnabled)" = true ]'

section "remove respects a choice made in between"
reset
"$PROG" sync --quiet >/dev/null 2>&1
as_login_user kwriteconfig6 --file "$K" --group Plugins --key forceblurEnabled --delete
"$PROG" remove --quiet >/dev/null 2>&1
check_that "better_blur_dx is back on" '[ "$(val better_blur_dxEnabled)" = true ]'
check_that "the entry that was deleted by hand stays deleted" '! grep -q "^forceblurEnabled" "$K"'

section "an effect enabled system-wide only"
reset
sed -i '/blur.*Enabled/d' "$K"
printf '[Plugins]\nsome_blur_forkEnabled=true\n' > "$SYSTEM_KWINRC"
"$PROG" sync --quiet >/dev/null 2>&1
check_that "it is switched off for the login user only" \
    '[ "$(val some_blur_forkEnabled)" = false ] && grep -q "some_blur_forkEnabled=true" "$SYSTEM_KWINRC"'
rm -f -- "$SYSTEM_KWINRC"

section "further effects on request"
reset
echo 'LOGIN_COMPOSITOR_EFFECTS="diminactive"' > "$TOOL_CONF"
"$PROG" sync --quiet >/dev/null 2>&1
check_that "diminactive is off too" '[ "$(val diminactiveEnabled)" = false ]'
rm -f -- "$TOOL_CONF"

section "a login user without compositor settings"
rm -f -- "$K"
out=$("$PROG" sync --quiet 2>&1)
rc=$?
check_that "no output, no error, no file created" '[ -z "$out" ] && [ "$rc" = 0 ] && [ ! -e "$K" ]'
check_that "status says there is nothing to do" \
    '"$PROG" status | grep -q "Login compositor: .*no third-party blur effect enabled"'

section "who may run login-compositor"
check_that "other users are turned away" \
    'runuser -u nobody -- "$PROG" login-compositor 2>&1 | grep -q "must be run as root"'

finish
