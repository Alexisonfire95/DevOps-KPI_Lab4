# Task Tracker (mywebapp)

Лабораторна робота №1: розгортання web-сервісу з автоматизацією (DevOps KPI).

## Варіант (N = 1)

- **N** — порядковий номер у списку групи: **1**
- **V2** = (N % 2) + 1 = **2** → конфігурація: файл `/etc/mywebapp/config.yaml`; БД: **PostgreSQL**
- **V3** = (N % 3) + 1 = **2** → застосунок: **Task Tracker**
- **V5** = (N % 5) + 1 = **2** → порт застосунку: **5200**

### Мережа

| Компонент | Адреса | Порт |
|-----------|--------|------|
| nginx | 0.0.0.0 | 80 |
| mywebapp | 127.0.0.1 | 5200 |
| PostgreSQL | 127.0.0.1 | 5432 |

## Веб-застосунок

Task Tracker — сервіс для відстеження задач.

- Поля задачі: `id`, `title`, `status`, `created_at`
- `GET /tasks` — список усіх задач
- `POST /tasks` (`{ "title": "..." }`) — створити задачу
- `POST /tasks/:id/done` — статус «виконано»
- `GET /health/alive` — завжди `200 OK`
- `GET /health/ready` — `200 OK`, якщо БД доступна; інакше `500`
- `GET /` — лише `text/html`, список ендпоінтів бізнес-логіки

API віддає `application/json` або `text/html` за заголовком `Accept` (простий HTML без JS/CSS).

## Стек

- Node.js 24 LTS, pnpm
- PostgreSQL
- nginx, systemd (socket activation)

### Локальна розробка

```bash
pnpm install
cp deploy/config.example.yaml config.local.yaml
pnpm run migrate -- --config config.local.yaml
pnpm start -- --config config.local.yaml
```

### API

| Метод | Шлях | Опис |
|-------|------|------|
| GET | / | Список ендпоінтів (text/html) |
| GET | /tasks | Список задач |
| POST | /tasks | Створити задачу `{ "title": "..." }` |
| POST | /tasks/:id/done | Відмітити задачу виконаною |
| GET | /health/alive | Стан процесу (не публікується через nginx) |
| GET | /health/ready | Готовність (БД) (не публікується через nginx) |

## Розгортання на ВМ

### Базовий образ та ресурси

- Образ: Ubuntu 22.04 LTS — `ubuntu/jammy64`
- Ресурси: 1 CPU, 1024 MB RAM
- Конфігурація застосунку: `/etc/mywebapp/config.yaml`

### Вхід на ВМ

- `vagrant up`, потім `vagrant ssh`
- Користувачі: `student`, `teacher`, `operator` — пароль `12345678` (зміна при першому вході)
- Користувач `vagrant` після provision заблокований
- Сервіс: системний користувач `mywebapp`

### Запуск автоматизації

```bash
vagrant up
```

Provision (`scripts/provision.sh`): пакети, користувачі, PostgreSQL, копія застосунку в `/opt/mywebapp`, `config.yaml`, systemd socket activation, nginx, `/home/student/gradebook`.

Після provision: http://localhost:8080 (порт 80 гостя проброшений на 8080 хоста).

### Тестування

З хоста:

```bash
curl http://localhost:8080/
curl http://localhost:8080/tasks
curl -X POST http://localhost:8080/tasks -H "Content-Type: application/json" -d "{\"title\":\"Test\"}"
```

Health зсередини ВМ:

```bash
vagrant ssh
curl http://127.0.0.1:5200/health/alive
curl http://127.0.0.1:5200/health/ready
```

Користувач `operator`:

```bash
sudo systemctl status mywebapp
sudo systemctl restart mywebapp
sudo systemctl reload nginx
```

## Docker Compose (ЛР2)

Для контейнеризації та локального запуску застосунку у зв'язці з базою даних **PostgreSQL** та проксі-сервером **Nginx** використовується **Docker Compose**.

### Мережа та архітектура в Docker

Усі три сервіси запускаються в ізольованій мережі типу bridge під назвою `mywebapp-net`:
- **db** (`postgres:17-alpine`): База даних. Доступна за внутрішнім іменем хоста `db:5432`. Дані зберігаються у persistent volume `mywebapp-db-data`. Реалізовано healthcheck за допомогою `pg_isready`.
- **web** (Node.js застосунок на базі `node:24-alpine`): Веб-сервер, що працює на порту `5200`. Перед запуском застосунку скрипт `scripts/docker-entrypoint.sh` автоматично генерує `/etc/mywebapp/config.yaml`, очікує готовності БД та накочує міграції. Реалізовано healthcheck через `wget` на `/health/alive`.
- **nginx** (`nginx:1.27-alpine`): Зворотний проксі (reverse proxy), що приймає зовнішні запити на порту `8080` та перенаправляє їх на сервіс `web:5200`. Доступ до `/health` та `/health/` ззовні заблоковано.

### Запуск додатку

1. Переконайтеся, що Docker Daemon запущено на вашому комп'ютері.
2. Запустіть усі сервіси командою:
   ```bash
   docker compose up -d --build
   ```
3. Переглянути статус контейнерів та їхнє здоров'я (healthcheck):
   ```bash
   docker compose ps
   ```
4. Перегляд логів окремого сервісу або всього стеку:
   ```bash
   docker compose logs -f web
   ```

### Тестування API через Nginx

Перевірити роботу застосунку з хоста можна аналогічно до ЛР1, але через порт **8080**:

```bash
# Перевірка головної сторінки (вимагає Accept: text/html)
curl.exe -i -H "Accept: text/html" http://localhost:8080/

# Отримання списку задач
curl.exe -i http://localhost:8080/tasks

# Створення нової задачі (приклад для Windows PowerShell з екрануванням або через файл)
# Запишіть JSON у файл task.json: {"title": "Test Task"}
# Тоді виконайте:
curl.exe -i -X POST -H "Content-Type: application/json" -d "@task.json" http://localhost:8080/tasks
```

### Перевірка безпеки (блокування health-ендпоінтів)

Nginx блокує зовнішні запити до `/health/alive` та `/health/ready` (повертає 404):
```bash
curl.exe -i http://localhost:8080/health/alive
```

### Перевірка персистентності бази даних

Створіть задачу, після чого зупиніть та видаліть контейнери:
```bash
docker compose down
```
Запустіть їх знову:
```bash
docker compose up -d
```
Створені задачі мають зберегтися, оскільки дані PostgreSQL знаходяться у named volume `mywebapp-db-data`.

### Зупинка та очищення

Щоб зупинити та видалити всі контейнери та створену мережу:
```bash
docker compose down
```
Щоб видалити також persistent volume з даними бази:
```bash
docker compose down -v
```

---

## Лабораторна робота №4: Infrastructure as Code (IaC: Terraform + Ansible)

Ця частина роботи присвячена декларативному опису інфраструктури за допомогою **Terraform** та управлінню конфігурацією за допомогою **Ansible**.

### 1. Схема інфраструктури та мережі

Система автоматично розгортається на дві віртуальні машини в межах ізольованої Host-Only мережі VirtualBox (`192.168.56.0/24`):

```
                       +----------------- VM1: worker -----------------+
                       | IP: 192.168.56.115                            |
                       | - Nginx (порт 80, публічний)                  |
                       | - Node.js App (порт 5200, тільки localhost)   |
                       +-----------------------------------------------+
                                              |
                                              | (з'єднання з БД)
                                              v
                       +------------------- VM2: db -------------------+
                       | IP: 192.168.56.116                            |
                       | - PostgreSQL (порт 5432, закритий ззовні)     |
                       +-----------------------------------------------+
```

*   **worker VM (`192.168.56.115`)**: працює як веб-сервер, приймає HTTP-запити на порту 80 через Nginx, який проксує їх на локальний порт Node.js застосунку (`127.0.0.1:5200`). Шляхи `/health/*` заблоковані на рівні конфігурації Nginx.
*   **db VM (`192.168.56.116`)**: містить СУБД PostgreSQL. Доступ до порту 5432 дозволено лише для самої машини та для `worker` VM. Доступ регулюється як на рівні брандмауера (`UFW`), так і на рівні конфігурації БД (`pg_hba.conf`).

---

### 2. Керування користувачами та правами

У конфігурації налаштовані такі користувачі:
1.  **`ansible`** (на обох ВМ): створюється автоматично на етапі ініціалізації через `cloud-init`. Має SSH-ключ розробника та повні права адміністратора без потреби вводу пароля (`NOPASSWD: ALL` в sudoers).
2.  **`teacher`** (на обох ВМ): створюється через Ansible для перевірки роботи. Має права адміністратора (sudo), пароль за замовчуванням — `12345678`.
3.  **`app`** (тільки на `worker` VM): системний користувач (`/usr/sbin/nologin`) з мінімальними правами. Від його імені працює сервіс `mywebapp`.
4.  **`operator`** (тільки на `worker` VM): створюється через Ansible для оперативного керування веб-застосунком та проксі-сервером. Пароль — `12345678`.
    *   Має обмежений доступ до `sudo` без пароля **виключно** для наступного списку команд:
        *   `sudo systemctl start mywebapp`
        *   `sudo systemctl stop mywebapp`
        *   `sudo systemctl restart mywebapp`
        *   `sudo systemctl status mywebapp`
        *   `sudo systemctl reload nginx`

---

### 3. Інструкція із запуску розгортання

Розгортання складається з двох послідовних етапів.

#### Етап А: Provisioning (Terraform на хост-системі Windows)

1.  Генеруємо ISO-образи ініціалізації `cloud-init` (вони містять метадані та SSH-ключ для користувача `ansible`):
    ```bash
    python make_cidata.py
    ```
2.  Переконайтеся, що шлях до VirtualBox доданий до змінних оточення (наприклад, `C:\Program Files\Oracle\VirtualBox` для Windows).
3.  Ініціалізуйте та застосуйте Terraform-маніфест:
    ```bash
    terraform init
    terraform apply -auto-approve
    ```
    *Terraform автоматично згенерує файл `ansible/inventory.ini` з актуальними IP-адресами створених віртуальних машин.*

#### Етап Б: Configuration Management (Ansible у WSL2)

1.  Увійдіть до WSL2 (Ubuntu).
2.  Запустіть Ansible Playbook для повної конфігурації обох вузлів:
    ```bash
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
    ```
    *Ansible встановить усі залежності (Node.js 22, pnpm, PostgreSQL, Nginx), налаштує конфігураційні файли з шаблонів Jinja2, виконає міграції, налаштує брандмауер UFW та запустить сервіси.*

---

### 4. Верифікація роботи та безпеки

Після завершення розгортання виконайте наступні перевірки:

1.  **Доступність застосунку через Nginx:**
    ```bash
    curl http://192.168.56.115/tasks
    ```
    *Має повернути список задач (код 200).*

2.  **Блокування `/health` через Nginx:**
    ```bash
    curl -I http://192.168.56.115/health/alive
    ```
    *Має повернути статус `404 Not Found`.*

3.  **Локальний доступ до порту застосунку:**
    *Зсередини `worker` VM:*
    ```bash
    curl http://127.0.0.1:5200/health/ready
    ```
    *Має повернути статус `200 OK` (якщо база даних доступна).*

4.  **Перевірка захисту бази даних:**
    *Спроба прямого підключення до БД з хост-машини або з іншого вузла (окрім `worker` та `db`):*
    ```bash
    nc -z -v -w3 192.168.56.116 5432
    ```
    *Повинна завершитися тайм-аутом (завдяки налаштуванням UFW на db VM).*

5.  **Перевірка файлу оцінок:**
    *Файл `/home/student/gradebook` на обох ВМ містить номер варіанту:*
    ```bash
    cat /home/student/gradebook
    # Виведе: 1
    ```
