#!/bin/bash
# Restore the network after Tunnelblick hangs.
# Usage: sudo bash reset.sh [--lang en|ru]

set -euo pipefail

LANGUAGE=${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}
case "${1:-}" in
  --lang)
    if [ "$#" -ne 2 ]; then
      echo 'Usage: reset.sh [--lang en|ru]' >&2
      exit 2
    fi
    LANGUAGE=$2
    ;;
  '') ;;
  *)
    echo 'Usage: reset.sh [--lang en|ru]' >&2
    exit 2
    ;;
esac
case "$LANGUAGE" in
  ru*) LANGUAGE=ru ;;
  *) LANGUAGE=en ;;
esac

DAEMON="net.tunnelblick.openvpn.process-network-changes"
VPN_PATTERN='^(/Applications/Tunnelblick[.]app|/Library/Application Support/Tunnelblick/Tunnelblick[.]app)/Contents/Resources/openvpn/[^ ]+/openvpn([[:space:]]|$)'
STEP=0
UI_STOPPED=0
WIFI_OFF=0

message() {
  if [ "$LANGUAGE" = ru ]; then
    printf '%s\n' "$1"
  else
    printf '%s\n' "$2"
  fi
}

progress() {
  STEP=$((STEP + 1))
  if [ "$LANGUAGE" = ru ]; then
    printf 'PROGRESS\t%s\t6\t%s\n' "$STEP" "$1"
  else
    printf 'PROGRESS\t%s\t6\t%s\n' "$STEP" "$2"
  fi
}

kill_optional() {
  if /usr/bin/pkill "$@"; then
    return 0
  else
    local result=$?
    [ "$result" -eq 1 ]
  fi
}

cleanup() {
  if [ "$WIFI_OFF" -eq 1 ]; then
    networksetup -setairportpower en0 on || true
  fi
  if [ "$UI_STOPPED" -eq 1 ]; then
    /usr/bin/pkill -CONT -x Tunnelblick >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [ "$LANGUAGE" = ru ]; then NONE=нет; else NONE=none; fi

progress 'Останавливаю Tunnelblick и OpenVPN' 'Stopping Tunnelblick and OpenVPN'
for NAME in Tunnelblick tunnelblickd; do
  PIDS=$(/usr/bin/pgrep -x "$NAME" | tr '\n' ' ' || true)
  echo "  $NAME: ${PIDS:-$NONE}"
done
PIDS=$(/usr/bin/pgrep -f "$VPN_PATTERN" | tr '\n' ' ' || true)
echo "  OpenVPN: ${PIDS:-$NONE}"
if /usr/bin/pgrep -x Tunnelblick >/dev/null; then
  kill_optional -STOP -x Tunnelblick
  UI_STOPPED=1
fi
kill_optional -9 -f "$VPN_PATTERN"
kill_optional -9 -x tunnelblickd
kill_optional -9 -x Tunnelblick
UI_STOPPED=0
sleep 0.5
if /usr/bin/pgrep -x Tunnelblick >/dev/null ||
   /usr/bin/pgrep -x tunnelblickd >/dev/null ||
   /usr/bin/pgrep -f "$VPN_PATTERN" >/dev/null; then
  message '  Ошибка: процессы Tunnelblick или OpenVPN остались запущены' \
          '  Error: Tunnelblick or OpenVPN processes are still running' >&2
  exit 1
fi
message '  процессов Tunnelblick и OpenVPN не осталось' \
        '  no Tunnelblick or OpenVPN processes remain'

progress "Снимаю демон $DAEMON" "Unloading daemon $DAEMON"
if launchctl print "system/$DAEMON" >/dev/null 2>&1; then
  launchctl bootout "system/$DAEMON"
  if launchctl print "system/$DAEMON" >/dev/null 2>&1; then
    message '  Ошибка: демон остался зарегистрирован' \
            '  Error: daemon is still registered' >&2
    exit 1
  fi
  message '  снят' '  unloaded'
else
  message '  не зарегистрирован, пропускаю' '  not registered; skipped'
fi

progress 'Чищу DNS-ключи в Setup и State' 'Removing DNS keys from Setup and State'
for DOMAIN in Setup State; do
  KEYS=$(scutil <<< "list $DOMAIN:/Network/Service/.*/DNS" \
         | awk '{print $NF}' \
         | grep "^$DOMAIN:/Network/Service/") || true
  if [ -z "$KEYS" ]; then
    message "  $DOMAIN: чисто" "  $DOMAIN: clean"
  else
    for K in $KEYS; do
      echo "  remove $K"
      scutil <<< "remove $K"
    done
  fi
done

progress 'Перезапускаю Wi-Fi' 'Restarting Wi-Fi'
networksetup -setairportpower en0 off
WIFI_OFF=1
sleep 1
networksetup -setairportpower en0 on
WIFI_OFF=0
sleep 4

progress 'Чищу кэш резолвера' 'Flushing resolver cache'
dscacheutil -flushcache
killall -HUP mDNSResponder

progress 'Проверяю DNS' 'Checking DNS'
scutil --dns | sed -n '1,12p'
if /usr/bin/pgrep -x Tunnelblick >/dev/null ||
   /usr/bin/pgrep -f "$VPN_PATTERN" >/dev/null; then
  message '  Ошибка: Tunnelblick или OpenVPN снова запущен и может изменить DNS' \
          '  Error: Tunnelblick or OpenVPN restarted and may change DNS' >&2
  exit 1
fi
