#!/bin/sh
# Railway start script for OpenPost.
# - makes the Railway volume at /data writable for the image's "openpost" user
# - derives the public URL, port and CPU/memory limits from Railway
# - creates the instance admin from OPENPOST_ADMIN_EMAIL / OPENPOST_ADMIN_PASSWORD
#   on first boot (on a private port, before the public port opens), so no
#   stranger can register first and become admin
# - exits non-zero whenever OpenPost stops unexpectedly, so Railway restarts it
set -eu

log() { echo "[railway-start] $*"; }
DATA=/data

# ---- Railway settings ------------------------------------------------------
export PORT="${PORT:-8080}"
export OPENPOST_PORT="$PORT"
if [ -z "${OPENPOST_APP_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export OPENPOST_APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
if [ -z "${OPENPOST_APP_URL:-}" ]; then
  log "OPENPOST_APP_URL is empty and the service has no public Railway domain. Add a domain or set OPENPOST_APP_URL."
  exit 1
fi
export OPENPOST_APP_URL="${OPENPOST_APP_URL%/}"
export OPENPOST_PUBLIC_URL="${OPENPOST_PUBLIC_URL:-$OPENPOST_APP_URL}"
# Railway's edge proxy reaches the service from its private ranges; trust only
# those so the real client IP (rate limits) and https (Secure cookies) are seen.
export OPENPOST_TRUSTED_PROXY_CIDRS="${OPENPOST_TRUSTED_PROXY_CIDRS:-100.64.0.0/10,fd00::/8}"
# Maintainer diagnostics to app.openpo.st stay off unless the deployer opts in.
export OPENPOST_DIAGNOSTICS_ENABLED="${OPENPOST_DIAGNOSTICS_ENABLED:-false}"
# The admin is created below; afterwards nobody else can sign up unless the
# deployer sets OPENPOST_DISABLE_REGISTRATIONS=false.
export OPENPOST_DISABLE_REGISTRATIONS="${OPENPOST_DISABLE_REGISTRATIONS:-true}"
export OPENPOST_DATABASE_PATH="${OPENPOST_DATABASE_PATH:-$DATA/db/openpost.db}"
export OPENPOST_MEDIA_PATH="${OPENPOST_MEDIA_PATH:-$DATA/media}"

for v in OPENPOST_JWT_SECRET OPENPOST_ENCRYPTION_KEY; do
  eval "val=\${$v:-}"
  if [ "${#val}" -lt 32 ]; then log "$v must be set to at least 32 characters."; exit 1; fi
done

# ---- CPU and memory from the cgroup (Railway shows the host's CPUs) ---------
cpus=1
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ "${period:-0}" -gt 0 ]; then
    cpus=$(( (quota + period - 1) / period ))
  else
    cpus=$(nproc 2>/dev/null || echo 2)
  fi
fi
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 8 ] && cpus=8
[ "$cpus" -lt 2 ] && thr=2 || thr=$cpus
export GOMAXPROCS="${GOMAXPROCS:-$thr}"
export OPENPOST_FFMPEG_THREADS="${OPENPOST_FFMPEG_THREADS:-$thr}"
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
  mem=$(cat /sys/fs/cgroup/memory.max)
  if [ "$mem" != "max" ]; then export GOMEMLIMIT="$(( mem / 1048576 * 70 / 100 ))MiB"; fi
fi
log "cpus=$cpus GOMAXPROCS=$GOMAXPROCS GOMEMLIMIT=${GOMEMLIMIT:-unset} url=$OPENPOST_APP_URL"

# ---- volume -----------------------------------------------------------------
mkdir -p "$DATA/db" "$DATA/media"
find "$DATA" \( ! -user openpost -o ! -group openpost \) -exec chown openpost:openpost {} + 2>/dev/null || true

# BusyBox su execs the shell, which execs OpenPost, so $! below is OpenPost itself.
AS_OPENPOST="su -p -s /bin/sh openpost -c"

# ---- first-boot admin -------------------------------------------------------
MARK="$DATA/.railway-admin-created"
if [ ! -f "$MARK" ]; then
  email="${OPENPOST_ADMIN_EMAIL:-}"; pass="${OPENPOST_ADMIN_PASSWORD:-}"
  if [ -z "$email" ] || [ "${#pass}" -lt 12 ]; then
    log "OPENPOST_ADMIN_EMAIL must be set and OPENPOST_ADMIN_PASSWORD must have at least 12 characters."; exit 1
  fi
  bport=18080
  log "first boot: creating the admin account on private port $bport"
  OPENPOST_PORT=$bport OPENPOST_DISABLE_REGISTRATIONS=true $AS_OPENPOST "exec /app/openpost all" > /tmp/bootstrap.log 2>&1 &
  bpid=$!
  i=0
  until wget -q -T 3 -O /dev/null "http://127.0.0.1:$bport/api/v1/ready" 2>/dev/null; do
    i=$((i+1))
    if ! kill -0 "$bpid" 2>/dev/null || [ $i -gt 180 ]; then
      log "OpenPost did not start for the admin bootstrap:"; tail -n 40 /tmp/bootstrap.log; exit 1
    fi
    sleep 1
  done
  esc() { printf %s "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
  umask 077
  printf '{"email":"%s","password":"%s"}' "$(esc "$email")" "$(esc "$pass")" > /tmp/register-body.json
  set +e
  wget -q -S -T 30 -O /tmp/register.json --header 'Content-Type: application/json' \
    --post-file /tmp/register-body.json "http://127.0.0.1:$bport/api/v1/auth/register" 2>/tmp/register.hdr
  set -e
  rm -f /tmp/register-body.json; umask 022
  code=$(grep -o 'HTTP/1\.[01] [0-9][0-9][0-9]' /tmp/register.hdr | tail -n 1 | cut -d' ' -f2)
  case "${code:-000}" in
    200|201)
      if grep -q '"is_admin":true' /tmp/register.json; then log "admin account created for $email"
      else log "account created but it is not the instance admin (an account already existed)"; fi ;;
    403|409) log "an account already exists (HTTP $code); not creating another admin" ;;
    *) log "admin bootstrap failed (HTTP ${code:-none}):"; cat /tmp/register.hdr | tail -n 3; tail -n 20 /tmp/bootstrap.log; kill "$bpid" 2>/dev/null; exit 1 ;;
  esac
  rm -f /tmp/register.json /tmp/register.hdr
  kill -TERM "$bpid" 2>/dev/null || true
  wait "$bpid" 2>/dev/null || true
  touch "$MARK"; chown openpost:openpost "$MARK"
fi

# ---- run --------------------------------------------------------------------
stopping=0
$AS_OPENPOST "exec /app/openpost all" &
pid=$!
trap 'stopping=1; kill -TERM "$pid" 2>/dev/null' TERM INT
set +e
wait "$pid"; rc=$?
# wait returns early when a trapped signal arrives; wait for the real exit
while kill -0 "$pid" 2>/dev/null; do wait "$pid"; rc=$?; done
if [ "$stopping" = 1 ]; then exit 0; fi
log "OpenPost exited unexpectedly (code $rc)"
[ "$rc" -eq 0 ] && rc=1
exit "$rc"
