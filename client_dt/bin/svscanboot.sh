#!/bin/sh

# Get out of wherever we are
cd /

# Sane umask
umask 022

# Remove some ulimits that might be set
ulimit -t unlimited
ulimit -m unlimited
ulimit -f unlimited
ulimit -v unlimited

PATH=/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/X11R6/bin

exec </dev/null
exec >/dev/null
exec 2>/dev/null

/bin/svc -dx /service/* /service/*/log

env - PATH=$PATH svscan /service 2>&1 | \
env - PATH=$PATH readproctitle service errors: .....................................................................................................................................................................................................................................................................................
