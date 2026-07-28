# 📟 VPS Monitor Bot

Bot Telegram untuk memantau VPS secara realtime — status sistem, monitoring file, keamanan SSH, aktivitas user, dan laporan otomatis via Telegram.

> **Dibuat dengan Bash murni** — zero dependencies dari package registry. Cuma butuh 5 paket Linux standar.

---

## 📋 Fitur

### 🤖 Telegram Commands

| Perintah | Trigger | Fungsi | Read/Write |
|---|---|---|---|
| `/start` | Manual | Pesan selamat datang & info bot | 🔍 Read |
| `/help` | Manual | Daftar semua perintah & fitur (sama seperti /start) | 🔍 Read |
| `/status` | Manual | Cek status VPS lengkap: website (HTTP code + time), CPU, RAM, Disk, Docker (running/stopped), uptime, hostname | 🔍 Read |
| `/checkfile` | Manual | Cek perubahan file di folder project (via `git status`, hormati `.gitignore`) | 🔍 Read |
| `/discardchanges` | Manual | Batalkan semua perubahan file — `git restore` + `git clean -fd` | ⚡ Write |
| — | Otomatis (inotify) | Notifikasi realtime setiap ada file create/modify/delete/move | 🔍 Read |
| — | Otomatis (auth.log) | Notifikasi realtime SSH login/logout, failed login, sudo command | 🔍 Read |
| — | Otomatis (timer) | Laporan status VPS setiap 3 jam | 🔍 Read |

### 🖥️ Monitoring Sistem (`/status`)
- **Website Check** — HTTP status code + response time
- **CPU Usage** — persentase pemakaian realtime
- **RAM Usage** — used/total + persentase
- **Disk Usage** — used/total + persentase
- **Docker Status** — daftar container running 🟢 dan stopped 🔴
- **Uptime** — lama VPS menyala

### 👁️ Realtime File Monitor (inotify)
- Deteksi event: `create`, `modify`, `delete`, `moved_to`, `moved_from`
- Auto-ignore folder via `IGNORE_REGEX` (vendor, node_modules, storage/logs, dll.)
- **Auto-ignore `.gitignore`** — file yang masuk `.gitignore` tidak dikirim notifikasinya
- Notifikasi langsung ke Telegram setiap ada perubahan file

### 🔐 Auth Monitor (realtime)
- ✅ **SSH login berhasil** — user, IP, port
- 🚫 **SSH login gagal** — user, IP, port (failed password)
- 🚪 **SSH logout** — user
- 🛡️ **Sudo command** — user + command yang dijalankan
- Debounce 30 detik anti-spam per IP/user

### 📊 Laporan Otomatis
- Status VPS dikirim otomatis setiap **3 jam** via systemd timer

---

## 📦 Persyaratan

- **OS:** Linux (Ubuntu/Debian/CentOS/RHEL)
- **Akses root** (sudo)
- **Bot Token** dari [@BotFather](https://t.me/botfather)
- **Chat ID** dari [@userinfobot](https://t.me/userinfobot)

### Paket yang Dibutuhkan

Installer akan menginstall otomatis jika belum ada:

| Paket | Fungsi |
|---|---|
| `curl` | HTTP request ke Telegram API + website check |
| `jq` | Parse JSON response Telegram |
| `bc` | Kalkulasi persentase CPU |
| `inotify-tools` | Realtime file monitoring |
| `git` | File change detection + discard + .gitignore filter |

---

## 🚀 Cara Install

### 1. Clone repo di VPS

```bash
git clone https://github.com/amirulhidayah/Telegram-Bot-VPS.git
cd Telegram-Bot-VPS
```

### 2. Jalankan installer

```bash
sudo bash installer.sh
```

### 3. Masukkan konfigurasi

Installer akan meminta input interaktif:

1. **BOT_TOKEN** — token dari [@BotFather](https://t.me/botfather) (wajib)
2. **CHAT_ID** — ID chat dari [@userinfobot](https://t.me/userinfobot) (wajib)
3. **CHECK_URL** — URL website yang mau dimonitor statusnya
4. **WATCH_PATH** — path folder project yang mau dipantau perubahannya

### 4. Pilih fitur yang aktif

Setelah konfigurasi, installer akan menampilkan daftar fitur yang bisa di-toggle:

```
╔══════════════════════════════════════════════╗
║         PILIH FITUR YANG AKTIF             ║
╚══════════════════════════════════════════════╝

SSH Login (berhasil) [Y/n]: y
SSH Logout [Y/n]: y
SSH Failed Login [y/N]: n    ← nonaktif default (hindari spam bruteforce)
Sudo Command [Y/n]: y
File Monitor (realtime) [Y/n]: y
Auto Report (3 jam) [Y/n]: y
Command /status [Y/n]: y
Command /checkfile [Y/n]: y
Command /discardchanges [Y/n]: y
```

Default **Y** untuk fitur yang aman, default **n** untuk failed login yang rawan spam.

### 5. Verifikasi

Cek Telegram kamu, akan ada pesan:

```
✅ VPS Monitor Bot berhasil diinstall!
```

Kemudian kirim `/start` atau `/help` untuk melihat daftar perintah sesuai fitur yang kamu aktifkan.

---

## 📌 Manajemen Service

```bash
# Cek status bot
systemctl status telegram-bot

# Cek status file monitor
systemctl status file-monitor

# Cek status auth monitor
systemctl status auth-monitor

# Cek jadwal laporan
systemctl list-timers

# Lihat log realtime
journalctl -u telegram-bot -f
journalctl -u file-monitor -f
journalctl -u auth-monitor -f
```

---

## 👀 Pantau Aktivitas User di VPS Secara Realtime

Auth monitor bot hanya mengirim notifikasi untuk event **SSH login/logout, failed login, dan sudo**. Tapi kalau kamu ingin **melihat langsung apa yang sedang dilakukan user yang login**, kamu juga bisa pakai command-command Linux bawaan berikut via terminal:

### Siapa yang sedang login sekarang?

```bash
# User yang sedang login + sejak kapan + dari mana
w

# Versi lebih ringkas
who
who -u        # tampilkan juga idle time
```

Contoh output `w`:
```
 21:35:19 up 3 days,  2:15,  2 users,  load average: 0.08, 0.03, 0.01
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
ubuntu   pts/0    103.45.67.89     21:30    2.00s  0.08s  0.01s nano index.php
root     pts/1    103.45.67.89     21:32    1:05   0.05s  0.05s htop
```

Dari situ kamu bisa lihat:
- **User ubuntu** login dari IP `103.45.67.89`, sedang edit `index.php` pakai nano
- **User root** login dari IP yang sama, sedang jalanin `htop`

### Riwayat login

```bash
# 10 login terakhir (termasuk yang gagal)
last -10

# Login gagal saja
lastb -10

# User yang sudah logout
last | head -20
```

### Semua user yang aktif (termasuk non-SSH)

```bash
# Semua session login (tty, pts, dll)
loginctl list-sessions

# Detail session tertentu
loginctl session-status <session-id>
```

### Proses yang sedang berjalan

```bash
# Semua proses, realtime (interaktif)
htop

# Format non-interactive — update tiap 2 detik
watch -n 2 'ps aux --sort=-%cpu | head -20'
```

### Network — koneksi aktif

```bash
# Listening port + koneksi aktif
ss -tulpn

# Koneksi yang sudah established (berguna untuk lihat SSH dari IP mana aja)
ss -tnp state established

# Semua koneksi SSH aktif
ss -tnp | grep :22
```

### Log aktivitas secara realtime

```bash
# Semua login/logout SSH secara live (sama seperti yang dikirim bot)
journalctl -u sshd -f --no-hostname

# Filter hanya yang sukses login
journalctl -u sshd -f --no-hostname -g "Accepted"

# Semua sudo command secara live
journalctl -f -t sudo

# Auth log langsung
tail -f /var/log/auth.log
```

### Dashboard realtime (gabungan)

Kalau mau lihat semuanya sekaligus, buka terminal terpisah dan jalankan:

```bash
# Di terminal 1 — pantau SSH login/logout langsung
journalctl -u sshd -f --no-hostname -o short-iso

# Di terminal 2 — pantau sudo command
journalctl -f -t sudo

# Di terminal 3 — lihat siapa yang online
watch -n 5 'echo "=== USER LOGIN ===" && w && echo "" && echo "=== SSH CONNECTIONS ===" && ss -tnp state established'
```

---

## 🗑️ Uninstall

```bash
cd Telegram-Bot-VPS
sudo bash uninstaller.sh
```

> **Keamanan:** Kamu harus mengetik `UNINSTALL` (kapital) untuk konfirmasi.
> **Backup:** `config.sh` otomatis dibackup ke `/tmp/` sebelum dihapus.
> **Paket:** Paket sistem (curl, jq, dll) **tidak** ikut dihapus.

---

## 🏗️ Struktur Folder

```
/opt/vps-monitor/
├── config.sh                # Konfigurasi bot
├── bot.sh                   # Long polling bot
├── report.sh                # Script laporan 3 jam
├── script/
│   ├── send.sh              # Kirim pesan Telegram
│   ├── status.sh            # Ambil status VPS
│   ├── check-file.sh        # Cek perubahan file
│   ├── discard-changes.sh   # Batalkan perubahan file
│   ├── watch-file.sh        # Realtime file monitor
│   └── watch-auth.sh        # Realtime auth log monitor
├── services/
│   ├── telegram-bot.service
│   ├── telegram-report.service
│   ├── telegram-report.timer
│   ├── file-monitor.service
│   └── auth-monitor.service
├── state/
│   └── offset.dat           # Offset polling Telegram
└── logs/
```

---

## ⚙️ Konfigurasi

Semua konfigurasi ada di `/opt/vps-monitor/config.sh`:

```bash
# Telegram
BOT_TOKEN="xxx"
CHAT_ID="xxx"

# Website
CHECK_URL="https://domainanda.com"

# Interval laporan (detik)
REPORT_INTERVAL=10800    # 3 jam

# File monitor
WATCH_PATH="/var/www/html/project"
IGNORE_REGEX="(^|/)(vendor|node_modules|storage/logs|storage/framework|bootstrap/cache|\.git)(/|$)"

# Feature Toggles (true/false)
SSH_LOGIN_ENABLED=true
SSH_LOGOUT_ENABLED=true
SSH_FAILED_LOGIN_ENABLED=false    # default off — rawan spam bruteforce
SUDO_ENABLED=true
FILE_MONITOR_ENABLED=true
AUTO_REPORT_ENABLED=true
STATUS_ENABLED=true
CHECKFILE_ENABLED=true
DISCARD_ENABLED=true
```

Setelah mengubah config, restart service yang terpengaruh:

```bash
# Ubah auth monitor
sudo systemctl restart auth-monitor

# Ubah file monitor
sudo systemctl restart file-monitor

# Ubah timer report
sudo systemctl restart telegram-report.timer

# Ubah bot commands
sudo systemctl restart telegram-bot
```

---

## 🛡️ Keamanan

- Bot hanya merespon **satu CHAT_ID** yang dikonfigurasi — chat lain diabaikan
- Semua script dijalankan sebagai root (perlu akses system)
- Auth monitor memiliki **debounce 30 detik** untuk mencegah spam notifikasi
- File monitor memiliki **dua lapis filter**: `IGNORE_REGEX` + `git check-ignore` (`.gitignore`)
- Git **safe.directory** otomatis dikonfigurasi supaya bot (root) bisa akses repo milik user lain

---

## 📝 Catatan

- **Timezone:** WITA (Asia/Makassar) — bisa diubah di setiap script
- **Git:** Fitur `/checkfile` dan `/discardchanges` butuh folder project yang sudah di-*init* sebagai git repository lokal. `watch-file.sh` juga hormati `.gitignore`
- **Docker:** Status docker otomatis muncul walau cuma 1 container
- **Auth.log:** Auth monitor butuh file `/var/log/auth.log` (standarnya Ubuntu/Debian, di CentOS mungkin `/var/log/secure`)
- **Update bot:** `git pull origin main` lalu `sudo bash installer.sh` lagi — konfigurasi lama tetap aman
- **Safe.directory:** Bot otomatis daftarkan WATCH_PATH ke `safe.directory` supaya root bisa akses repo milik user lain tanpa error