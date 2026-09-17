# Tunnelblick Reset

[English](README.md)

Приложение для строки меню macOS восстанавливает сеть после зависания Tunnelblick. Значок с большой `T` и маленькой `b` занимает одно место; прямоугольная рамка с закруглёнными углами показывает прогресс. В меню виден текущий этап и неактивная строка **«Состояние»**. После успешного восстановления приложение запускает Tunnelblick, показывает галочку 5 секунд и возвращает монограмму.

Интерфейс и скрипт поддерживают русский и английский. Приложение следует языковым настройкам macOS; отдельный скрипт использует язык терминала или параметр `--lang en|ru`.

Скрипт останавливает Tunnelblick, `tunnelblickd` и запущенный им OpenVPN, снимает `net.tunnelblick.openvpn.process-network-changes`, удаляет DNS-ключи из `scutil`, перезапускает Wi-Fi, очищает кэш резолвера и проверяет DNS. Если VPN-процессы остаются запущенными, скрипт завершится с ошибкой. При ошибке после отключения Wi-Fi он попытается включить Wi-Fi обратно.

## Установка релиза

В [релизе 1.1.0](https://github.com/viktoraseev/dns-reset-tunnelblick/releases/tag/v1.1.0) есть отдельные архивы для Apple Silicon и Intel. Установить приложение можно через [Homebrew cask](https://github.com/viktoraseev/homebrew):

```sh
brew tap viktoraseev/homebrew https://github.com/viktoraseev/homebrew.git
brew install --cask viktoraseev/homebrew/dns-reset-tunnelblick
```

## Сборка текущих исходников

Нужны macOS 13 или новее, Xcode Command Line Tools, Tunnelblick в `/Applications/Tunnelblick.app` и права администратора.

```sh
./build.sh
open "$HOME/Applications/Tunnelblick Reset.app"
```

`./build-release.sh` собирает отдельные ZIP-архивы для Apple Silicon и Intel в `dist/` с подписью ad hoc; команда ничего не публикует. У проекта пока нет сертификата Developer ID и нотариального заверения Apple. Если Gatekeeper блокирует приложение из скачанного архива, проверьте его исходники и снимите карантин только с этого приложения, если доверяете ему.

## Touch ID

Приложение вызывает `sudo -A`. Для авторизации пальцем в `/etc/pam.d/sudo_local` нужна строка из файла [`sudo_local`](sudo_local):

```text
auth       sufficient     pam_tid.so
```

Эта системная настройка PAM влияет и на другие команды `sudo`. Если файл уже есть, сохраните остальные записи. Приложение не показывает окно ввода пароля: при недоступности Touch ID восстановление завершится ошибкой. Отдельный `./run.sh` допускает обычный запрос пароля.

## Ручной запуск

`sudo bash reset.sh [--lang en|ru]` выполняет шесть этапов восстановления без запуска Tunnelblick. `./run.sh` восстанавливает сеть и запускает Tunnelblick от имени текущего пользователя. В приложении запуск Tunnelblick — седьмой этап.

В `reset.sh` Wi-Fi интерфейс задан как `en0`; для Mac с другой схемой интерфейсов его надо изменить. Служба `net.tunnelblick.tunnelblick.tunnelblickd` остаётся зарегистрированной, чтобы Tunnelblick можно было снова запустить. Новое VPN-подключение может опять установить корпоративный DNS.

Автозапуск не настроен. Пункт **«Выход»** завершает приложение. Положение значка можно изменить перетаскиванием с зажатой Command.

## Лицензия

MIT. См. [LICENSE](LICENSE).
