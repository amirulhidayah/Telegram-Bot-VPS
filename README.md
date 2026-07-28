# 📟 VPS Monitor Bot

Bot Telegram untuk memantau VPS secara realtime — status sistem, monitoring file, keamanan SSH, dan laporan otomatis via Telegram.

> **Dibuat dengan Bash murni** — zero dependencies dari package registry. Cuma butuh 5 paket Linux standar.

---

## 📋 Fitur

### 🤖 Telegram Commands

| Perintah | Fungsi |
|---|---|
| `/status` | Cek status VPS lengkap: CPU, RAM, Disk, Docker, Uptime + status website |
| `/checkfile` | Cek perubahan file di folder project (via git status) |
| `/discardchanges` | Batalkan semua perubahan file (git restore + git clean) |

### 🖥️ Monitoring Sistem (`/status`)
- **CPU Usage** — persentase pemakaian realtime
- **RAM Usage** — used/total + persentase
- **Disk Usage** — used/total + persentase
- **Docker Status** — daftar container running 🟢 dan stopped 🔴
- **Website Check** — HTTP status code + response time

### 👁️ Realtime File Monitor (inotify)
- Deteksi event: `create`, `modify`, `delete`, `moved_to`, `moved_from`
- Auto-ignore: `vendor/`, `node_modules/`, `storage/logs/`, `.git/`, dll.
- Notifikasi langsung ke Telegram setiap ada perubahan file

### 🔐 Auth Monitor (realtime)
- ✅ SSH login berhasil — user, IP, port
- 🚫 SSH login gagal — user, IP, port
- 🚪 SSH logout — user
- 🛡️ Sudo command — user + command
- Debounce 30 detik anti-spam

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
| `git` | File change detection + discard |

---

## 🚀 Cara Install

### 1. Upload script ke VPS

```bash
# Upload dari local ke VPS (jalankan di komputer kamu)
scp installer.sh root@IP_VPS:~/installer.sh
```

Atau download langsung di VPS:

```bash
# (nanti kalau sudah di GitHub/public)
wget -O installer.sh https://...
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

### 4. Verifikasi

Cek Telegram kamu, akan ada pesan:

```
✅ VPS Monitor Bot berhasil diinstall!
```

Kemudian kirim `/status` ke bot untuk cek hasilnya.

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

# Lihat log
journalctl -u telegram-bot -f
journalctl -u file-monitor -f
journalctl -u auth-monitor -f
```

---

## 🗑️ Uninstall

Jalankan script `uninstaller.sh` yang sudah disiapkan:

```bash
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
```

Setelah mengubah config, restart service:

```bash
systemctl restart telegram-bot
```

---

## 🛡️ Keamanan

- Bot hanya merespon **satu CHAT_ID** yang dikonfigurasi — chat lain diabaikan
- Semua script dijalankan sebagai root (perlu akses system)
- Auth monitor memiliki **debounce 30 detik** untuk mencegah spam notifikasi
- File monitor memiliki **ignore list** untuk folder yang tidak perlu dipantau

---

## 📝 Catatan

- **Timezone:** WITA (Asia/Makassar) — bisa diubah di setiap script
- **Git:** Fitur `/checkfile` dan `/discardchanges` butuh folder project yang sudah di-*init* sebagai git repository lokal
- **Docker:** Status docker otomatis muncul walau cuma 1 container
- **Auth.log:** Auth monitor butuh file `/var/log/auth.log` (standarnya ada di Debian/Ubuntu, di CentOS mungkin di `/var/log/secure`)