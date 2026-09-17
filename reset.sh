#!/bin/bash
# Восстанавливает сеть после зависания Tunnelblick.
# Запуск: sudo bash reset.sh

set -euo pipefail

DAEMON="net.tunnelblick.openvpn.process-network-changes"
VPN_PATTERN='^(/Applications/Tunnelblick[.]app|/Library/Application Support/Tunnelblick/Tunnelblick[.]app)/Contents/Resources/openvpn/[^ ]+/openvpn([[:space:]]|$)'
STEP=0
UI_STOPPED=0
WIFI_OFF=0

progress() {
  STEP=$((STEP + 1))
  printf 'PROGRESS\t%s\t6\t%s\n' "$STEP" "$1"
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

progress 'Останавливаю Tunnelblick и OpenVPN'
for NAME in Tunnelblick tunnelblickd; do
  PIDS=$(/usr/bin/pgrep -x "$NAME" | tr '\n' ' ' || true)
  echo "  $NAME: ${PIDS:-нет}"
done
PIDS=$(/usr/bin/pgrep -f "$VPN_PATTERN" | tr '\n' ' ' || true)
echo "  OpenVPN: ${PIDS:-нет}"
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
  echo '  Ошибка: процессы Tunnelblick или OpenVPN остались запущены' >&2
  exit 1
fi
echo '  процессов Tunnelblick и OpenVPN не осталось'

progress "Снимаю демон $DAEMON"
if launchctl print "system/$DAEMON" >/dev/null 2>&1; then
  launchctl bootout "system/$DAEMON"
  if launchctl print "system/$DAEMON" >/dev/null 2>&1; then
    echo '  Ошибка: демон остался зарегистрирован' >&2
    exit 1
  fi
  echo '  снят'
else
  echo '  не зарегистрирован, пропускаю'
fi

progress 'Чищу DNS-ключи в Setup и State'
for DOMAIN in Setup State; do
  KEYS=$(scutil <<< "list $DOMAIN:/Network/Service/.*/DNS" \
         | awk '{print $NF}' \
         | grep "^$DOMAIN:/Network/Service/") || true
  if [ -z "$KEYS" ]; then
    echo "  $DOMAIN: чисто"
  else
    for K in $KEYS; do
      echo "  remove $K"
      scutil <<< "remove $K"
    done
  fi
done

progress 'Перезапускаю Wi-Fi'
networksetup -setairportpower en0 off
WIFI_OFF=1
sleep 1
networksetup -setairportpower en0 on
WIFI_OFF=0
sleep 4

progress 'Чищу кэш резолвера'
dscacheutil -flushcache
killall -HUP mDNSResponder

progress 'Проверяю DNS'
scutil --dns | sed -n '1,12p'
if /usr/bin/pgrep -x Tunnelblick >/dev/null ||
   /usr/bin/pgrep -f "$VPN_PATTERN" >/dev/null; then
  echo '  Ошибка: Tunnelblick или OpenVPN снова запущен и может изменить DNS' >&2
  exit 1
fi
