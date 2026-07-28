#!/bin/bash
# =============================================================================
# VPS Monitor Bot — Uninstaller
# =============================================================================
# Jalankan: sudo bash uninstaller.sh
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
echo "║       VPS Monitor Bot — Uninstaller                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Script ini akan MENGHAPUS:"
echo "  • Semua file di $BASE"
echo -e "  • Systemd services berikut:"
echo "    - telegram-bot.service"
echo "    - telegram-report.service"
echo "    - telegram-report.timer"
echo "    - file-monitor.service"
echo "    - auth-monitor.service"
echo ""
echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  PERINGATAN: Aksi ini tidak bisa dibatalkan! ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
echo ""

read -p "$(echo -e "${RED}Ketik ${BOLD}UNINSTALL${NC}${RED} untuk melanjutkan: ${NC}")" confirm

if [[ "$confirm" != "UNINSTALL" ]]; then
  echo -e "${YELLOW}Uninstall dibatalkan.${NC}"
  exit 1
fi

# ─── Root check ──────────────────────────────────────────────────────────────
echo ""
log "Memeriksa akses root..."
if [[ $EUID -ne 0 ]]; then
  err "Script ini harus dijalankan sebagai root (sudo bash uninstaller.sh)"
  exit 1
fi
ok "Akses root terkonfirmasi"

# ─── Stop & Disable Services ─────────────────────────────────────────────────
echo ""
log "Menghentikan dan menonaktifkan services..."

SERVICES="telegram-bot telegram-report.timer file-monitor telegram-report auth-monitor"

for svc in $SERVICES; do
  if systemctl list-units --full --all 2>/dev/null | grep -q "$svc"; then
    systemctl stop "$svc" 2>/dev/null || true
    systemctl disable "$svc" 2>/dev/null || true
    ok "$svc dihentikan & dinonaktifkan"
  else
    log "$svc tidak ditemukan, skip"
  fi
done

# ─── Remove Systemd Files ────────────────────────────────────────────────────
echo ""
log "Menghapus file systemd..."

FILES=(
  "/etc/systemd/system/telegram-bot.service"
  "/etc/systemd/system/telegram-report.service"
  "/etc/systemd/system/telegram-report.timer"
  "/etc/systemd/system/file-monitor.service"
  "/etc/systemd/system/auth-monitor.service"
)

for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    rm -f "$f"
    ok "  ${f} dihapus"
  else
    log "  ${f} tidak ditemukan"
  fi
done

systemctl daemon-reload 2>/dev/null || true
systemctl reset-failed 2>/dev/null || true
ok "Systemd daemon di-reload"

# ─── Remove VPS Monitor Directory ───────────────────────────────────────────
echo ""
log "Menghapus direktori $BASE..."

if [ -d "$BASE" ]; then
  # Backup config.sh sebelum hapus
  if [ -f "$BASE/config.sh" ]; then
    BACKUP_FILE="/tmp/vps-monitor-config-backup-$(date +%Y%m%d-%H%M%S).sh"
    cp "$BASE/config.sh" "$BACKUP_FILE"
    ok "Backup config tersimpan di: $BACKUP_FILE"
  fi

  rm -rf "$BASE"
  ok "  $BASE beserta seluruh isinya dihapus"
else
  log "  $BASE tidak ditemukan"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       UNINSTALL SELESAI! 🗑️                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Yang telah dihapus:${NC}"
echo "  • Semua file VPS Monitor Bot"
echo "  • Systemd services & timer"
echo ""
echo -e "  ${YELLOW}Catatan:${NC}"
echo "  • Paket (curl, jq, bc, inotify-tools, git) tidak dihapus"
echo "    karena mungkin dipakai aplikasi lain."
echo "  • Jika ingin hapus paket: sudo apt remove curl jq bc inotify-tools git"
echo ""

if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
echo -e "  ${CYAN}Backup config tersimpan di:${NC}"
echo "    $BACKUP_FILE"
echo "  Jika ingin install ulang, gunakan file backup ini sebagai referensi."
fi
echo ""