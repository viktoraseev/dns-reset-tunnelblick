# DNS Reset for Tunnelblick

Небольшое приложение для строки меню macOS. Значок `TB` занимает одно место. Пункт «Починить сеть после Tunnelblick» запускает восстановление с правами администратора, показывает прогресс и затем открывает Tunnelblick. После успеха галочка отображается 10 секунд.

Скрипт останавливает Tunnelblick, `tunnelblickd` и запущенный им OpenVPN, снимает `net.tunnelblick.openvpn.process-network-changes`, удаляет DNS-ключи из `scutil`, перезапускает Wi-Fi, очищает кэш резолвера и проверяет итоговый DNS. Он завершится с ошибкой, если VPN-процессы остались запущены. При ошибке после отключения Wi-Fi скрипт попытается включить его обратно.

## Установка

Нужны macOS 13 или новее, Tunnelblick в `/Applications/Tunnelblick.app` и права администратора. Сборки доступны для Apple Silicon (`arm64`) и Intel (`x86_64`) в [GitHub Releases](https://github.com/viktoraseev/dns-reset-tunnelblick/releases).

Через [общий Homebrew tap](https://github.com/viktoraseev/homebrew):

```sh
brew tap viktoraseev/homebrew https://github.com/viktoraseev/homebrew.git
brew install --cask viktoraseev/homebrew/dns-reset-tunnelblick
```

Приложение подписано ad hoc, так как у проекта пока нет сертификата Developer ID и нотариального заверения Apple. Если macOS блокирует запуск, снимите карантин **только с этого приложения**, предварительно убедившись, что оно получено из указанного репозитория:

```sh
xattr -dr com.apple.quarantine '/Applications/DNS Reset.app'
```

Для ручной установки распакуйте архив своей архитектуры и перенесите `DNS Reset.app` в `/Applications`. Запуск: `open '/Applications/DNS Reset.app'`. Приложение появляется только в строке меню; в Dock его нет.

## Touch ID

Приложение вызывает `sudo -A`. Для авторизации пальцем в `/etc/pam.d/sudo_local` должна быть строка из файла [`sudo_local`](sudo_local):

```text
auth       sufficient     pam_tid.so
```

Настройка PAM системная и распространяется на остальные вызовы `sudo`. Если файл уже существует, сохраните его прочие настройки. Приложение не показывает окно ввода пароля: если Touch ID недоступен, операция завершится ошибкой. Для ручного запуска с обычным запросом пароля используйте `./run.sh` из исходников.

## Сборка из исходников

Нужны Xcode Command Line Tools (`xcode-select --install`). `./build.sh` собирает приложение в `~/Applications`. `./build-release.sh` создаёт в `dist/` отдельные подписанные ad hoc ZIP-архивы для `arm64` и `x86_64` и печатает SHA-256.

`sudo bash reset.sh` выполняет шесть этапов восстановления без повторного запуска Tunnelblick. `./run.sh` выполняет эти этапы и запускает Tunnelblick от имени текущего пользователя. В приложении запуск Tunnelblick — седьмой этап.

Автозапуск не настроен. Пункт «Выход» завершает приложение. Положение значка можно менять перетаскиванием с зажатой Command.

## Ограничения

Wi-Fi интерфейс в скрипте задан как `en0`. Перед использованием на Mac с другой схемой интерфейсов измените `reset.sh`. Служба `net.tunnelblick.tunnelblick.tunnelblickd` остаётся зарегистрированной, чтобы Tunnelblick снова запускался. После нового подключения VPN он может вновь установить корпоративный DNS.

## Лицензия

MIT, см. [LICENSE](LICENSE).
