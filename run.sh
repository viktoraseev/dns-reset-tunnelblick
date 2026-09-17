#!/bin/bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo 'Запускайте run.sh без sudo: скрипт сам запросит права для восстановления сети.' >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
sudo /bin/bash "$SCRIPT_DIR/reset.sh"
echo 'PROGRESS 7/7 Запускаю Tunnelblick'
/usr/bin/open '/Applications/Tunnelblick.app'
