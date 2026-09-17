#!/bin/bash
set -euo pipefail

LANGUAGE=${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}
case "$LANGUAGE" in
  ru*) LANGUAGE=ru ;;
  *) LANGUAGE=en ;;
esac

if [ "$EUID" -eq 0 ]; then
  if [ "$LANGUAGE" = ru ]; then
    echo 'Запускайте run.sh без sudo: скрипт сам запросит права для восстановления сети.' >&2
  else
    echo 'Run run.sh without sudo; it will request administrator access itself.' >&2
  fi
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
sudo /bin/bash "$SCRIPT_DIR/reset.sh" --lang "$LANGUAGE"
if [ "$LANGUAGE" = ru ]; then
  echo 'PROGRESS 7/7 Запускаю Tunnelblick'
else
  echo 'PROGRESS 7/7 Launching Tunnelblick'
fi
/usr/bin/open '/Applications/Tunnelblick.app'
