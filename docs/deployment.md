# Контрольная работа 2 Вариант 18

Осадчев Никита, ЭФБО-04-24. Для номера 18 используются `notes.devops.local`, порт `8002`, ветка `kr2/variant-18`.

Исходный шаблон: https://gitverse.ru/dgimatdinov/kr2-template, коммит `3ee6c4bfda24df8cb4d61f8a27031813b3238338`. Ревизия приведена в [template-audit.md](template-audit.md). Логика `app.py` и состав `requirements.txt` сохранены; в `app.py` добавлен только комментарий `# KR2: Osadchev` для проверки кэша.

## Стенд

VM `devops-vm`, Ubuntu Server 24.04.5, Host-only `192.168.56.101`, SSH по ключу на порту 2222. Клиент — Ubuntu WSL `DevOps-P6`. В SSH-конфигурации клиента есть псевдоним `devops`. Файл hosts Windows и WSL содержит `192.168.56.101 notes.devops.local`.

Предыдущий проект остаётся в `~/app`, его аудит — `~/scripts/audit.sh`. Новый проект размещён в `~/kr2`. UFW, SSH и `/etc/nginx/sites-available/devops-site` не меняются. До работы создан `06-before-kr2`, сохранён `~/ufw-before-kr2.txt`; итоговый снимок — `07-kr2`.

## Доставка и секрет

Команды на клиенте из корня проекта:

```sh
rsync -avz --delete --exclude=.env --exclude=.git --chmod=D755,F644 --dry-run ./ devops:kr2/
rsync -avz --delete --exclude=.env --exclude=.git --chmod=D755,F644 ./ devops:kr2/
```

Исключение `.env` защищает серверный файл и от перезаписи, и от удаления при `--delete`. `--chmod` нормализует права файлов с Windows-диска.

На VM под пользователем devops файл `.env` создаётся один раз:

```sh
cd ~/kr2
umask 077
test -e .env || printf 'REDIS_PASSWORD=%s\n' "$(openssl rand -hex 32)" > .env
chmod 600 .env
unset REDIS_PASSWORD
docker compose config --quiet
docker compose up -d --build
```

Рабочий пароль создан на сервере, не выводится и не переносится на клиент. Пароль исходного шаблона считается раскрытым и не используется. `REDIS_HOST=redis` и `STUDENT=Osadchev` заданы явно в Compose. Нельзя публиковать вывод `docker compose config` без `--quiet` или полный `docker inspect` контейнеров: они раскрывают окружение и аргументы с паролем.

## HTTPS

На VM под root выполняются:

```sh
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/ssl/private/kr2.key -out /etc/ssl/certs/kr2.crt \
  -subj '/CN=notes.devops.local' -addext 'subjectAltName=DNS:notes.devops.local'
chmod 600 /etc/ssl/private/kr2.key
chmod 644 /etc/ssl/certs/kr2.crt
install -o root -g root -m 644 /home/devops/kr2/config/nginx/kr2 /etc/nginx/sites-available/kr2
ln -sfn /etc/nginx/sites-available/kr2 /etc/nginx/sites-enabled/kr2
nginx -t && systemctl reload nginx
```

Клиент получает только публичный сертификат:

```sh
scp devops:/etc/ssl/certs/kr2.crt ~/kr2.crt
curl -I http://notes.devops.local
curl --cacert ~/kr2.crt https://notes.devops.local/
curl --cacert ~/kr2.crt https://notes.devops.local/whoami
curl -m 3 http://notes.devops.local:8002/health
```

Ожидается 301 на HTTP, успешный HTTPS с `kr2.crt`, `scheme: https`, `client: 192.168.56.1`, `host: notes.devops.local`, недоступность прямого порта. На сервере для локальной проверки можно применять `--resolve notes.devops.local:443:127.0.0.1`; тогда `client` равен 127.0.0.1. Приложение получает TCP-соединение от Nginx, исходный адрес передаётся заголовком X-Real-IP.

## Контроль

`scripts/audit.sh` сохраняет 14 проверок предыдущей работы и добавляет пять проверок раздела 6. Запускается на VM после `sudo -v`. `scripts/test-audit-port.sh` временно публикует 8002 на всех интерфейсах, сохраняет отрицательный результат в `/tmp/kr2-audit-negative.log`, затем автоматически возвращает loopback и проверяет код 0. Это учебный тест; UFW не меняется. `scripts/check-secret.sh` проверяет секрет только на VM, без вывода его значения.

Том `kr2_redis_data` сохраняется при `docker compose down`. Флаг `-v` не используется. Оба сервиса имеют `restart: unless-stopped`, приложение ждёт `redis: service_healthy`. Команда Redis начинается с `redis-server`, поэтому официальный entrypoint понижает привилегии; процесс проверяется через `docker compose top`.

Pull Request в `main` оставляется открытым до защиты.
