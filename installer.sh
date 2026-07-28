#!/bin/bash
# =============================================================================
# VPS Monitor Bot — Interactive Installer
# =============================================================================
# Jalankan: sudo bash installer.sh
# =============================================================================

set -e

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

log()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

BASE="/opt/vps-monitor"

# ─── Header ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║         VPS Monitor Bot — Interactive Installer     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Akan menginstall:"
echo "  • Bot Telegram (/status, /checkfile, /discardchanges)"
echo "  • Realtime file monitor (inotify)"
echo "  • Laporan otomatis setiap 3 jam"
echo "  • Systemd services + timer"
echo ""
echo -e "${YELLOW}Pastikan kamu sudah menyiapkan:${NC}"
echo "  • BOT_TOKEN dari @BotFather"
echo "  • CHAT_ID dari @userinfobot"
echo "  • URL website yang ingin dimonitor"
echo "  • Path folder project yang ingin dipantau"
echo ""

read -p "$(echo -e "${YELLOW}Lanjutkan instalasi? [Y/n]${NC} ")" confirm
confirm="${confirm:-Y}"
if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
  echo -e "${RED}Instalasi dibatalkan.${NC}"
  exit 1
fi

# ─── Root check ──────────────────────────────────────────────────────────────
echo ""
log "Memeriksa akses root..."
if [[ $EUID -ne 0 ]]; then
  err "Script ini harus dijalankan sebagai root (sudo bash installer.sh)"
  exit 1
fi
ok "Akses root terkonfirmasi"

# ─── OS Detection ────────────────────────────────────────────────────────────
log "Mendeteksi sistem operasi..."
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS="$ID"
  VER="$VERSION_ID"
else
  OS=$(uname -s)
  VER=$(uname -r)
fi
ok "Sistem: $OS $VER"

# ─── Prerequisites ───────────────────────────────────────────────────────────
echo ""
log "Memeriksa paket yang dibutuhkan..."

PACKAGES=""
command -v curl >/dev/null 2>&1 || PACKAGES="$PACKAGES curl"
command -v jq >/dev/null 2>&1   || PACKAGES="$PACKAGES jq"
command -v bc >/dev/null 2>&1   || PACKAGES="$PACKAGES bc"
command -v inotifywait >/dev/null 2>&1 || PACKAGES="$PACKAGES inotify-tools"
command -v git >/dev/null 2>&1  || PACKAGES="$PACKAGES git"

if [ -n "$PACKAGES" ]; then
  warn "Paket berikut belum terinstall:${PACKAGES}"
  read -p "$(echo -e "${YELLOW}Install sekarang? [Y/n]${NC} ")" inst_pkg
  inst_pkg="${inst_pkg:-Y}"
  if [[ "$inst_pkg" == "Y" || "$inst_pkg" == "y" ]]; then
    log "Menginstall paket..."
    if command -v apt >/dev/null 2>&1; then
      apt update -qq && apt install -y -qq $PACKAGES
    elif command -v yum >/dev/null 2>&1; then
      yum install -y -q $PACKAGES
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y -q $PACKAGES
    else
      err "Tidak bisa mendeteksi package manager. Install manual: apt install $PACKAGES"
      exit 1
    fi
    ok "Paket berhasil diinstall"
  else
    warn "Lanjutkan tanpa menginstall paket (beberapa fitur mungkin tidak berfungsi)"
  fi
else
  ok "Semua paket sudah terinstall"
fi

# ─── Configuration Input ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║           KONFIGURASI BOT TELEGRAM           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

# BOT_TOKEN
while [ -z "$BOT_TOKEN" ]; do
  read -p "$(echo -e "${CYAN}BOT_TOKEN${NC} (dari @BotFather) : ")" BOT_TOKEN
  if [ -z "$BOT_TOKEN" ]; then
    err "BOT_TOKEN tidak boleh kosong"
  fi
done
ok "BOT_TOKEN tersimpan"

# CHAT_ID
while [ -z "$CHAT_ID" ]; do
  read -p "$(echo -e "${CYAN}CHAT_ID${NC} (dari @userinfobot)  : ")" CHAT_ID
  if [ -z "$CHAT_ID" ]; then
    err "CHAT_ID tidak boleh kosong"
  fi
done
ok "CHAT_ID tersimpan"

echo ""

# CHECK_URL
read -p "$(echo -e "${CYAN}CHECK_URL${NC} (website, contoh: https://domainanda.com) : ")" CHECK_URL
CHECK_URL="${CHECK_URL:-https://domainanda.com}"
ok "CHECK_URL: $CHECK_URL"

echo ""

# WATCH_PATH
echo -e "${YELLOW}Path folder project yang mau dipantau perubahannya.${NC}"
echo -e "${YELLOW}Misal: /var/www/html/project atau /home/user/project${NC}"
read -p "$(echo -e "${CYAN}WATCH_PATH${NC}                                : ")" WATCH_PATH
while [ -z "$WATCH_PATH" ]; do
  warn "WATCH_PATH tidak boleh kosong"
  read -p "$(echo -e "${CYAN}WATCH_PATH${NC}                                : ")" WATCH_PATH
done
ok "WATCH_PATH: $WATCH_PATH"

echo ""

# ─── Create Directory Structure ──────────────────────────────────────────────
echo ""
log "Membuat struktur folder..."
mkdir -p "$BASE/script" "$BASE/state" "$BASE/logs" "$BASE/services"
ok "Struktur folder dibuat di $BASE"

# ─── Write config.sh ─────────────────────────────────────────────────────────
log "Menulis config.sh..."
cat > "$BASE/config.sh" << 'CONFIGEOF'
#!/bin/bash

# ========== TELEGRAM ==========
BOT_TOKEN="__BOT_TOKEN__"
CHAT_ID="__CHAT_ID__"

# ========== WEBSITE ==========
CHECK_URL="__CHECK_URL__"

# ========== INTERVAL ==========
REPORT_INTERVAL=10800

# ========== FILE MONITOR ==========
WATCH_PATH="__WATCH_PATH__"
IGNORE_REGEX="(^|/)(vendor|node_modules|storage/logs|storage/framework|bootstrap/cache|\.git)(/|$)"

# ========== AUTH MONITOR ==========
SSH_PORT=22
AUTH_LOG="/var/log/auth.log"
CONFIGEOF

# Replace placeholders
sed -i "s|__BOT_TOKEN__|$BOT_TOKEN|g" "$BASE/config.sh"
sed -i "s|__CHAT_ID__|$CHAT_ID|g" "$BASE/config.sh"
sed -i "s|__CHECK_URL__|$CHECK_URL|g" "$BASE/config.sh"
sed -i "s|__WATCH_PATH__|$WATCH_PATH|g" "$BASE/config.sh"

chmod +x "$BASE/config.sh"
ok "config.sh ditulis"

# ─── Write send.sh ───────────────────────────────────────────────────────────
log "Menulis script/send.sh..."
cat > "$BASE/script/send.sh" << 'SENDEOF'
#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

TEXT="$1"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  --data-urlencode text="$TEXT" \
  > /dev/null
SENDEOF

chmod +x "$BASE/script/send.sh"
ok "send.sh ditulis"

# ─── Test send.sh ────────────────────────────────────────────────────────────
echo ""
log "Mengirim pesan tes ke Telegram..."
if "$BASE/script/send.sh" "✅ VPS Monitor Bot berhasil diinstall!

$(date +"%d-%m-%Y %H:%M:%S WITA")"; then
  ok "Pesan tes terkirim! Cek Telegram kamu."
else
  warn "Gagal mengirim pesan tes. Periksa BOT_TOKEN dan CHAT_ID."
fi

# ─── Write status.sh ─────────────────────────────────────────────────────────
log "Menulis script/status.sh..."
cat > "$BASE/script/status.sh" << 'STATUSEOF'
#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

#################################
# TIMEZONE WITA
#################################
export TZ="Asia/Makassar"

#################################
# WEBSITE CHECK
#################################
HTTP=$(curl -o /dev/null -s -w "%{http_code}" --max-time 10 "$CHECK_URL")
TIME=$(curl -o /dev/null -s -w "%{time_total}" --max-time 10 "$CHECK_URL")

if [ "$HTTP" = "200" ]; then
  WEB_STATUS="🟢 ONLINE WEBSITE"
else
  WEB_STATUS="🔴 DOWN WEBSITE"
fi

#################################
# VPS INFORMATION
#################################
HOST=$(hostname)
UPTIME=$(uptime -p | sed 's/up //')

# CPU Usage
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d ',')
if [ -z "$CPU_IDLE" ]; then
  CPU=0
else
  CPU=$(awk "BEGIN {printf \"%.0f\", 100-$CPU_IDLE}")
fi

# RAM Usage
RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_PERCENT=$(free | awk '/Mem:/ {printf("%.0f", $3/$2*100)}')

# Disk Usage
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')

#################################
# DOCKER INFORMATION
#################################
DOCKER_RUNNING=$(docker ps --format "{{.Names}}" | wc -l)
DOCKER_STOPPED=$(docker ps -a --filter "status=exited" --format "{{.Names}}" | wc -l)

DOCKER_LIST=$(docker ps -a --format "{{.Names}}|{{.Status}}" | while IFS="|" read -r NAME STATUS
do
  if [[ "$STATUS" == Up* ]]; then
    echo "🟢 $NAME"
  else
    echo "🔴 $NAME"
  fi
done)

#################################
# TIMESTAMP WITA
#################################
DATE=$(date +"%d-%m-%Y %H:%M:%S WITA")

#################################
# OUTPUT
#################################
cat <<EOF
$WEB_STATUS
HTTP : $HTTP
Time : ${TIME}s

🖥 VPS
Host : $HOST
CPU  : ${CPU}%
RAM  : $RAM_USED / $RAM_TOTAL ($RAM_PERCENT%)
Disk : $DISK_USED / $DISK_TOTAL ($DISK_PERCENT)
Uptime : $UPTIME

🐳 DOCKER
Running : $DOCKER_RUNNING
Stopped : $DOCKER_STOPPED
$DOCKER_LIST

🕒 $DATE
EOF
STATUSEOF

chmod +x "$BASE/script/status.sh"
ok "status.sh ditulis"

# ─── Write check-file.sh ─────────────────────────────────────────────────────
log "Menulis script/check-file.sh..."
cat > "$BASE/script/check-file.sh" << 'CHECKEOF'
#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

export TZ="Asia/Makassar"

cd "$WATCH_PATH" || exit 1

STATUS=$(git status --short)

DATE=$(date +"%d-%m-%Y %H:%M:%S WITA")

if [ -z "$STATUS" ]; then
cat <<EOF
✅ Tidak ada perubahan file

🕒 $DATE
EOF
else
cat <<EOF
🚨 Perubahan file terdeteksi

$STATUS

🕒 $DATE
EOF
fi
CHECKEOF

chmod +x "$BASE/script/check-file.sh"
ok "check-file.sh ditulis"

# ─── Write discard-changes.sh ────────────────────────────────────────────────
log "Menulis script/discard-changes.sh..."
cat > "$BASE/script/discard-changes.sh" << 'DISCARDEOF'
#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

export TZ="Asia/Makassar"

cd "$WATCH_PATH" || exit 1

STATUS=$(git status --short)

DATE=$(date +"%d-%m-%Y %H:%M:%S WITA")

if [ -z "$STATUS" ]; then
cat <<EOF
✅ Tidak ada perubahan yang perlu dibatalkan.

🕒 $DATE
EOF
exit 0
fi

FILES="$STATUS"

git restore --staged .
git restore .
git clean -fd

cat <<EOF
✅ Perubahan berhasil dibatalkan.

File yang dipulihkan:

$FILES

Repository kembali ke commit terakhir.

🕒 $DATE
EOF
DISCARDEOF

chmod +x "$BASE/script/discard-changes.sh"
ok "discard-changes.sh ditulis"

# ─── Write watch-file.sh ─────────────────────────────────────────────────────
log "Menulis script/watch-file.sh..."
cat > "$BASE/script/watch-file.sh" << 'WATCHEOF'
#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

export TZ="Asia/Makassar"

inotifywait -m -r \
  -e create \
  -e modify \
  -e delete \
  -e moved_to \
  -e moved_from \
  --format "%e|%w|%f" \
  "$WATCH_PATH" |
while IFS="|" read -r EVENT DIR FILE
do

  FULL="${DIR}${FILE}"

  if [[ "$FULL" =~ $IGNORE_REGEX ]]; then
    continue
  fi

  # Skip file yang ada di .gitignore
  REL="${FULL#$WATCH_PATH/}"
  if git -C "$WATCH_PATH" check-ignore "$REL" &>/dev/null; then
    continue
  fi

  MESSAGE="🚨 FILE SYSTEM ALERT

Event :
$EVENT

File :
${FULL#$WATCH_PATH/}

🕒 $(date +"%d-%m-%Y %H:%M:%S WITA")"

  "$BASE_DIR/script/send.sh" "$MESSAGE"

done
WATCHEOF

chmod +x "$BASE/script/watch-file.sh"
ok "watch-file.sh ditulis"

# ─── Write bot.sh ───────────────────────────────────────────────────────────
log "Menulis bot.sh..."
cat > "$BASE/bot.sh" << 'BOTEOF'
#!/bin/bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$BASE_DIR/config.sh"

OFFSET_FILE="$BASE_DIR/state/offset.dat"

if [ ! -f "$OFFSET_FILE" ]; then
  echo "0" > "$OFFSET_FILE"
fi

while true
do
  OFFSET=$(cat "$OFFSET_FILE")

  JSON=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=30")
  COUNT=$(echo "$JSON" | jq '.result | length')

  if [ "$COUNT" -gt 0 ]; then
    echo "$JSON" | jq -c '.result[]' | while read -r UPDATE
    do
      UPDATE_ID=$(echo "$UPDATE" | jq '.update_id')
      NEXT_OFFSET=$((UPDATE_ID + 1))
      echo "$NEXT_OFFSET" > "$OFFSET_FILE"

      TEXT=$(echo "$UPDATE" | jq -r '.message.text // ""')
      CHAT=$(echo "$UPDATE" | jq -r '.message.chat.id')

      # Hanya layani CHAT_ID yang diizinkan
      if [ "$CHAT" != "$CHAT_ID" ]; then
        continue
      fi

      case "$TEXT" in
        "/status")
          MESSAGE=$("$BASE_DIR/script/status.sh")
          curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$CHAT_ID" \
            --data-urlencode text="$MESSAGE" \
            > /dev/null
          ;;
        "/checkfile")
          MESSAGE=$("$BASE_DIR/script/check-file.sh")
          curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$CHAT_ID" \
            --data-urlencode text="$MESSAGE" \
            > /dev/null
          ;;
        "/discardchanges")
          MESSAGE=$("$BASE_DIR/script/discard-changes.sh")
          curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$CHAT_ID" \
            --data-urlencode text="$MESSAGE" \
            > /dev/null
          ;;
        *)
          # abaikan perintah lain
          ;;
      esac
    done
  fi

  sleep 1
done
BOTEOF

chmod +x "$BASE/bot.sh"
ok "bot.sh ditulis"

# ─── Write report.sh ─────────────────────────────────────────────────────────
log "Menulis report.sh..."
cat > "$BASE/report.sh" << 'REPORTEOF'
#!/bin/bash
BASE_DIR="/opt/vps-monitor"
MESSAGE=$($BASE_DIR/script/status.sh)
$BASE_DIR/script/send.sh "$MESSAGE"
REPORTEOF

chmod +x "$BASE/report.sh"
ok "report.sh ditulis"

# ─── Write offset.dat ────────────────────────────────────────────────────────
echo "0" > "$BASE/state/offset.dat"
ok "state/offset.dat diinisialisasi"

# ─── Write Service Files ─────────────────────────────────────────────────────
log "Menulis service files..."

# telegram-bot.service
cat > "$BASE/services/telegram-bot.service" << 'TBOTEOF'
[Unit]
Description=Telegram VPS Status Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vps-monitor
ExecStart=/opt/vps-monitor/bot.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
TBOTEOF

# telegram-report.service
cat > "$BASE/services/telegram-report.service" << 'TREPORTEOF'
[Unit]
Description=Telegram VPS Status Report

[Service]
Type=oneshot
WorkingDirectory=/opt/vps-monitor
ExecStart=/opt/vps-monitor/report.sh
TREPORTEOF

# telegram-report.timer
cat > "$BASE/services/telegram-report.timer" << 'TTIMEREOF'
[Unit]
Description=Send VPS Status Every 3 Hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=3h
Persistent=true

[Install]
WantedBy=timers.target
TTIMEREOF

# file-monitor.service
cat > "$BASE/services/file-monitor.service" << 'FMONEOF'
[Unit]
Description=Realtime File Monitor
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vps-monitor
ExecStart=/opt/vps-monitor/script/watch-file.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
FMONEOF

# auth-monitor.service
cat > "$BASE/services/auth-monitor.service" << 'AMONEOF'
[Unit]
Description=Auth & Activity Monitor
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vps-monitor
ExecStart=/opt/vps-monitor/script/watch-auth.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
AMONEOF

ok "Service files ditulis"

# ─── Write watch-auth.sh ────────────────────────────────────────────────────
log "Menulis script/watch-auth.sh..."
cat > "$BASE/script/watch-auth.sh" << 'WATCHEOF'
#!/bin/bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

export TZ="Asia/Makassar"

AUTH_LOG="${AUTH_LOG:-/var/log/auth.log}"

if [ ! -f "$AUTH_LOG" ]; then
  exit 1
fi

# Debounce: track last notification time per IP/user to avoid spam
declare -A LAST_NOTIFY
DEBOUNCE_SEC=30

tail -F -n0 "$AUTH_LOG" 2>/dev/null | while IFS= read -r LINE
do

  DATE=$(date +"%d-%m-%Y %H:%M:%S WITA")

  # ─── SSH Login ───
  if echo "$LINE" | grep -qE 'sshd.*Accepted (password|publickey) for .* from '; then
    USER=$(echo "$LINE" | sed -n 's/.*for \([^]*\) from.*/\1/p')
    FROM=$(echo "$LINE" | sed -n 's/.*from \([^]*\) port.*/\1/p')
    PORT=$(echo "$LINE" | sed -n 's/.*port \([0-9]*\).*/\1/p')
    KEY="login:$FROM:$USER"
    NOW=$(date +%s)
    LAST=${LAST_NOTIFY[$KEY]:-0}
    if [ $((NOW - LAST)) -ge $DEBOUNCE_SEC ]; then
      LAST_NOTIFY[$KEY]=$NOW
      "$BASE_DIR/script/send.sh" "🔐 SSH LOGIN

User    : $USER
From    : $FROM
Port    : $PORT

🕒 $DATE"
    fi
  fi

  # ─── Failed Login ───
  if echo "$LINE" | grep -qE 'sshd.*Failed password for .* from '; then
    USER=$(echo "$LINE" | sed -n 's/.*for \([^]*\) from.*/\1/p')
    FROM=$(echo "$LINE" | sed -n 's/.*from \([^]*\) port.*/\1/p')
    PORT=$(echo "$LINE" | sed -n 's/.*port \([0-9]*\).*/\1/p')
    KEY="fail:$FROM:$USER"
    NOW=$(date +%s)
    LAST=${LAST_NOTIFY[$KEY]:-0}
    if [ $((NOW - LAST)) -ge $DEBOUNCE_SEC ]; then
      LAST_NOTIFY[$KEY]=$NOW
      "$BASE_DIR/script/send.sh" "🚫 FAILED SSH LOGIN

User    : $USER
From    : $FROM
Port    : $PORT

🕒 $DATE"
    fi
  fi

  # ─── Logout SSH ───
  if echo "$LINE" | grep -qE 'sshd.*session closed for user '; then
    USER=$(echo "$LINE" | sed -n 's/.*for user \([^]*\).*/\1/p')
    KEY="logout:$USER"
    NOW=$(date +%s)
    LAST=${LAST_NOTIFY[$KEY]:-0}
    if [ $((NOW - LAST)) -ge $DEBOUNCE_SEC ]; then
      LAST_NOTIFY[$KEY]=$NOW
      "$BASE_DIR/script/send.sh" "🚪 SSH LOGOUT

User    : $USER

🕒 $DATE"
    fi
  fi

  # ─── Sudo Command ───
  if echo "$LINE" | grep -qE 'sudo:.*COMMAND='; then
    USER=$(echo "$LINE" | sed -n 's/.*sudo: \([^]*\).*/\1/p')
    CMD=$(echo "$LINE" | sed -n 's/.*COMMAND=//p')
    # Skip sudo commands from auth-monitor itself to avoid loops
    if echo "$CMD" | grep -q 'watch-auth.sh'; then
      continue
    fi
    # Limit command display to 200 chars
    CMD_DISPLAY=$(echo "$CMD" | head -c 200)
    KEY="sudo:$USER:${CMD:0:50}"
    NOW=$(date +%s)
    LAST=${LAST_NOTIFY[$KEY]:-0}
    if [ $((NOW - LAST)) -ge $DEBOUNCE_SEC ]; then
      LAST_NOTIFY[$KEY]=$NOW
      "$BASE_DIR/script/send.sh" "🛡️ SUDO COMMAND

User    : $USER
Command : $CMD_DISPLAY

🕒 $DATE"
    fi
  fi

done
WATCHEOF

chmod +x "$BASE/script/watch-auth.sh"
ok "watch-auth.sh ditulis"


# ─── Permissions ─────────────────────────────────────────────────────────────
echo ""
log "Mengatur permission..."
chmod -R 755 "$BASE/script"/*.sh 2>/dev/null || true
chmod 644 "$BASE/config.sh"
chmod 644 "$BASE/state/offset.dat"
ok "Permission diatur"

# ─── Install Systemd Services ────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         INSTALL SYSTEMD SERVICES             ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Service yang akan diinstall:${NC}"
echo "  1) telegram-bot.service   — Bot Telegram (long polling)"
echo "  2) telegram-report.timer  — Laporan otomatis setiap 3 jam"
echo "  3) file-monitor.service   — Realtime file monitor (inotify)"
echo "  4) auth-monitor.service   — Realtime login & activity monitor"
echo ""

read -p "$(echo -e "${YELLOW}Install dan jalankan service sekarang? [Y/n]${NC} ")" inst_svc
inst_svc="${inst_svc:-Y}"

if [[ "$inst_svc" == "Y" || "$inst_svc" == "y" ]]; then

  # ── Telegram Bot ──
  echo ""
  log "Menginstall telegram-bot.service..."
  cp "$BASE/services/telegram-bot.service" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable telegram-bot
  systemctl start telegram-bot
  if systemctl is-active --quiet telegram-bot; then
    ok "telegram-bot.service aktif"
  else
    warn "telegram-bot.service gagal start — cek: journalctl -u telegram-bot -f"
  fi

  # ── Timer Report ──
  log "Menginstall telegram-report.timer..."
  cp "$BASE/services/telegram-report.service" /etc/systemd/system/
  cp "$BASE/services/telegram-report.timer" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable telegram-report.timer
  systemctl start telegram-report.timer
  if systemctl is-active --quiet telegram-report.timer; then
    ok "telegram-report.timer aktif"
  fi

  # ── File Monitor ──
  log "Menginstall file-monitor.service..."
  cp "$BASE/services/file-monitor.service" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable file-monitor
  systemctl start file-monitor
  if systemctl is-active --quiet file-monitor; then
    ok "file-monitor.service aktif"
  else
    warn "file-monitor.service gagal start — pastikan inotify-tools terinstall & WATCH_PATH valid"
  fi

  # ── Auth Monitor ──
  log "Menginstall auth-monitor.service..."
  cp "$BASE/services/auth-monitor.service" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable auth-monitor
  systemctl start auth-monitor
  if systemctl is-active --quiet auth-monitor; then
    ok "auth-monitor.service aktif"
  else
    warn "auth-monitor.service gagal start — pastikan /var/log/auth.log ada"
  fi

  echo ""
  ok "Semua service berhasil diinstall dan dijalankan!"

else
  warn "Service tidak diinstall. Kamu bisa install manual nanti dengan:"
  echo "  sudo cp $BASE/services/*.service /etc/systemd/system/"
  echo "  sudo cp $BASE/services/*.timer /etc/systemd/system/"
  echo "  sudo systemctl daemon-reload"
  echo "  sudo systemctl enable --now telegram-bot"
  echo "  sudo systemctl enable --now file-monitor"
  echo "  sudo systemctl enable --now auth-monitor"
  echo "  sudo systemctl enable --now telegram-report.timer"
  echo ""
  warn "Kamu bisa menjalankan bot secara manual:"
  echo "  cd $BASE && ./bot.sh"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          INSTALASI SELESAI! 🎉              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Lokasi instalasi:${NC}  $BASE"
echo ""
echo -e "  ${BOLD}Command Telegram yang tersedia:${NC}"
echo "    /status           — Cek status VPS"
echo "    /checkfile        — Cek perubahan file"
echo "    /discardchanges   — Batalkan perubahan file"
echo ""
echo -e "  ${BOLD}Management:${NC}"
echo "    systemctl status telegram-bot         — Cek status bot"
echo "    systemctl status file-monitor         — Cek status file monitor"
echo "    systemctl status auth-monitor         — Cek status auth monitor"
echo "    systemctl list-timers                 — Cek jadwal laporan"
echo "    journalctl -u telegram-bot -f         — Log bot"
echo "    journalctl -u file-monitor -f         — Log file monitor"
echo "    journalctl -u auth-monitor -f         — Log auth monitor"
echo ""
echo -e "  ${BOLD}Uninstall:${NC}"
echo "    Simpan file uninstaller.sh di folder yang sama"
echo "    dengan installer ini, lalu jalankan:"
echo "    sudo bash uninstaller.sh"
echo ""
echo -e "  ${YELLOW}Kirim /status ke bot Telegram kamu untuk mencoba!${NC}"
echo ""