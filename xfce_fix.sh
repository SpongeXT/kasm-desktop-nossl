#!/bin/bash
# XFCE startup repair: runs synchronously from vnc_startup.sh, BEFORE
# kasm_startup.sh launches the desktop, so it runs before startxfce4.
# Symptoms it addresses (seen in Altare logs 2026-11-23):
#   startxfce4 segfaults on DISPLAY=:1, "Window manager crashed, restarting",
#   stale /tmp/.X1-lock + /tmp/.X11-unix/X1 cannot be removed,
#   second startxfce4 says "X server already running on display :1",
#   vnc_startup.sh falls back to Openbox -> black screen, no panel/menu,
#   and apps pop "Unable to contact settings server".
# Root cause hypothesis: a crashed XFCE session leaves a stale saved
# session + xfconf state + X locks behind; the next startxfce4 tries to
# restore it and segfaults again. Restart alone does not clear it.
# This script clears exactly that stale state, idempotently.
set -x
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
rm -rf /home/kasm-user/.cache/sessions/*
rm -rf /home/kasm-user/.config/xfce4/xfconf/xfce-perchannel-xml/*
rm -rf /home/kasm-default-profile/.cache/sessions/*
# Drop huge core dumps left by the repeated segfaults (do not touch /data).
rm -f /home/kasm-user/core.* /core.* ./core.* 2>/dev/null || true
mkdir -p /run/user/1000 /tmp/.X11-unix
chown 1000:1000 /run/user/1000 2>/dev/null || true
chmod 700 /run/user/1000 2>/dev/null || true
chown -R 1000:1000 /home/kasm-user/.cache /home/kasm-user/.config 2>/dev/null || true
# Never let a crashing session fill the disk with core dumps again.
ulimit -c 0 2>/dev/null || true
echo "xfce-fix: stale XFCE session, xfconf cache and X locks cleared" >&2
