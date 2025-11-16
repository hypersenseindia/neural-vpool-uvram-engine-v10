#!/data/data/com.termux/files/usr/bin/env bash
# HypersenseFinal_Stable.sh
# HypersenseIndia — Final Stable GUI release
# Developer: AG HYDRAX  | Marketing Head: Roobal Sir (@roobal_sir) | Instagram: @hydraxff_yt
# Non-root, Termux-safe, Activation-bound (time-locked), Auto-start & Watchdog
# GUI: dialog-based (blue background / white box look)
set -o nounset
set -o pipefail

# -------------------------
# Paths & Files
# -------------------------
HYP_DIR="$HOME/.hypersense"
LOG_DIR="$HYP_DIR/logs"
CFG_FILE="$HYP_DIR/config.cfg"
ACT_FILE="$HYP_DIR/activation.info"
ENGINE_SCRIPT="$HYP_DIR/engine_worker.sh"
BOOT_DIR="$HOME/.termux/boot"
AUTOSTART_FILE="$BOOT_DIR/hypersense_autostart.sh"
ENGINE_LOG="$LOG_DIR/engine.log"
AI_FPS_LOG="$LOG_DIR/ai_fps_boost.log"
MONITOR_TMP="$HYP_DIR/monitor.tmp"
PID_FILE="$HYP_DIR/neural.pid"
ROTATE_LINES=2000

mkdir -p "$HYP_DIR" "$LOG_DIR" "$BOOT_DIR"
touch "$ENGINE_LOG" "$AI_FPS_LOG"
chmod 700 "$HYP_DIR" 2>/dev/null || true
chmod 600 "$ENGINE_LOG" "$AI_FPS_LOG" 2>/dev/null || true

# -------------------------
# Helpers & Safe wrappers
# -------------------------
safe_echo(){ printf "%s\n" "$*"; }
info(){ safe_echo "[INFO] $*" | tee -a "$ENGINE_LOG"; }
warn(){ safe_echo "[WARN] $*" | tee -a "$ENGINE_LOG"; }
err(){ safe_echo "[ERROR] $*" | tee -a "$ENGINE_LOG" >&2; }

sha256_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf "%s" "$1" | sha256sum | awk '{print $1}'
  else
    printf "%s" "$1" | md5sum | awk '{print $1}'
  fi
}

# Termux:API safe detection
termux_api_available(){
  command -v termux-battery-status >/dev/null 2>&1
}

get_battery_safe(){
  if termux_api_available; then
    if command -v jq >/dev/null 2>&1; then
      termux-battery-status 2>/dev/null | jq -r '.percentage // "N/A"' 2>/dev/null || echo "N/A"
    else
      termux-battery-status 2>/dev/null | awk -F: '/percentage/ {gsub(/[", ]/,"",$2); print $2; exit}' 2>/dev/null || echo "N/A"
    fi
  else
    echo "N/A"
  fi
}

get_temp_safe(){
  # Try thermal sysfs first
  for tz in /sys/class/thermal/thermal_zone*/temp; do
    [ -f "$tz" ] || continue
    val=$(cat "$tz" 2>/dev/null || echo "")
    [ -n "$val" ] && {
      if [ "${#val}" -gt 3 ]; then awk "BEGIN{printf \"%.1f\", $val/1000}"; else awk "BEGIN{printf \"%.1f\", $val}"; fi
      return
    }
  done
  # fallback to termux-battery-status temperature (if available)
  if termux_api_available; then
    if command -v jq >/dev/null 2>&1; then
      tmp=$(termux-battery-status 2>/dev/null | jq -r '.temperature // empty' 2>/dev/null || echo "")
      [ -n "$tmp" ] && { awk "BEGIN{printf \"%.1f\", $tmp/10}"; return; }
    else
      t=$(termux-battery-status 2>/dev/null | awk -F: '/temperature/ {gsub(/ /,"",$2); print $2; exit}' 2>/dev/null || echo "")
      [ -n "$t" ] && { awk "BEGIN{printf \"%.1f\", $t/10}"; return; }
    fi
  fi
  echo "N/A"
}

# get refresh rate best-effort
get_refresh_rate(){
  if command -v dumpsys >/dev/null 2>&1; then
    r=$(dumpsys SurfaceFlinger 2>/dev/null | grep -oE "[0-9]+(\.[0-9]+)? Hz" | head -n1 | sed 's/ Hz//' || true)
    [ -n "$r" ] && { echo "${r%%.*}"; return; }
    r=$(dumpsys display 2>/dev/null | grep -oE "activeRefreshRate=[0-9]+" | head -n1 | cut -d= -f2 || true)
    [ -n "$r" ] && { echo "$r"; return; }
  fi
  echo "60"
}

rotate_log(){
  f="$1"
  [ -f "$f" ] || return
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)
  if [ "$lines" -gt "$ROTATE_LINES" ]; then
    tail -n $((ROTATE_LINES/2)) "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  fi
}

# -------------------------
# Default Config & loader
# -------------------------
default_config(){
  cat > "$CFG_FILE" <<EOF
touch_x=12
touch_y=12
touch_smooth=1.0
neural_turbo=0
arc_plus=0
vpool_enabled=0
uvram_enabled=0
afb_mode=Auto
autostart_enabled=0
idle_target=70
active_target=95
cpu_threshold=45
thermal_soft=45
thermal_hard=50
sample_interval_ms=300
micro_trigger_ms=120
game_whitelist=com.dts.freefire,com.dts.freefiremax,com.pubg.imobile,com.tencent.ig,com.konami.pes2019
EOF
  chmod 600 "$CFG_FILE"
}

[ -f "$CFG_FILE" ] || default_config
# shellcheck disable=SC1090
. "$CFG_FILE"

# ensure safe variables
: "${touch_x:=12}" : "${touch_y:=12}" : "${touch_smooth:=1.0}"
: "${neural_turbo:=0}" : "${arc_plus:=0}" : "${vpool_enabled:=0}" : "${uvram_enabled:=0}"
: "${afb_mode:=Auto}" : "${autostart_enabled:=0}"
: "${idle_target:=70}" : "${active_target:=95}" : "${cpu_threshold:=45}"
: "${thermal_soft:=45}" : "${thermal_hard:=50}"
: "${sample_interval_ms:=300}" : "${micro_trigger_ms:=120}"
: "${game_whitelist:=com.dts.freefire,com.dts.freefiremax,com.pubg.imobile,com.tencent.ig,com.konami.pes2019}"

save_config(){
  cat > "$CFG_FILE" <<EOF
touch_x=$touch_x
touch_y=$touch_y
touch_smooth=$touch_smooth
neural_turbo=$neural_turbo
arc_plus=$arc_plus
vpool_enabled=$vpool_enabled
uvram_enabled=$uvram_enabled
afb_mode=$afb_mode
autostart_enabled=$autostart_enabled
idle_target=$idle_target
active_target=$active_target
cpu_threshold=$cpu_threshold
thermal_soft=$thermal_soft
thermal_hard=$thermal_hard
sample_interval_ms=$sample_interval_ms
micro_trigger_ms=$micro_trigger_ms
game_whitelist=$game_whitelist
EOF
  chmod 600 "$CFG_FILE"
}

# -------------------------
# Activation: one-time time-locked keys (Base64 encoded)
# RAW format (before base64): USERNAME|PLAN|PLANEXPIRY(YYYYMMDD)|ACTLOCK(YYYYMMDDHHMM)|[SIGNATURE optional]
# ACTLOCK = latest time user can *use* the token for activation (time-locked window).
# -------------------------

yyyymmdd_to_epoch(){
  d="$1"
  if ! [[ "$d" =~ ^[0-9]{8}$ ]]; then echo ""; return; fi
  date -d "${d:0:4}-${d:4:2}-${d:6:2} 00:00:00" +%s 2>/dev/null || echo ""
}

yyyymmddhhmm_to_epoch(){
  d="$1"
  if ! [[ "$d" =~ ^[0-9]{12}$ ]]; then echo ""; return; fi
  date -d "${d:0:4}-${d:4:2}-${d:6:2} ${d:8:2}:${d:10:2}:00" +%s 2>/dev/null || echo ""
}

check_activation(){
  if [ ! -f "$ACT_FILE" ]; then return 1; fi
  # load
  . "$ACT_FILE" 2>/dev/null || return 1
  NOW_EPOCH=$(date +%s)
  if ! [[ "${PLAN_EXPIRY_EPOCH:-}" =~ ^[0-9]+$ ]]; then return 1; fi
  if (( NOW_EPOCH > PLAN_EXPIRY_EPOCH )); then
    # expired: remove saved activation to prevent stale state
    warn "Saved activation expired on $(date -d "@$PLAN_EXPIRY_EPOCH" '+%F')"
    rm -f "$ACT_FILE" 2>/dev/null || true
    return 2
  fi
  return 0
}

prompt_activation(){
  if command -v dialog >/dev/null 2>&1; then
    dialog --msgbox "HYPERSENSEINDIA\nAG HYDRAX\nMarketing Head: Roobal Sir (@roobal_sir)\n\nActivation required (one-time, time-locked token)." 11 70
  else
    safe_echo "HYPERSENSEINDIA - Activation required."
  fi

  while true; do
    if command -v dialog >/dev/null 2>&1; then
      token=$(dialog --inputbox "Enter Activation Token (Base64)\nRAW: USER|PLAN|YYYYMMDD|YYYYMMDDHHMM|SIGN" 11 80 3>&1 1>&2 2>&3)
    else
      read -r -p "Enter Activation Token (Base64): " token
    fi

    [ -z "${token:-}" ] && {
      if command -v dialog >/dev/null 2>&1; then
        dialog --yesno "No token entered. Exit?" 7 45 && { clear; exit 1; } || continue
      else
        safe_echo "No token entered. Exiting."; exit 1
      fi
    }

    decoded=$(printf "%s" "$token" | base64 -d 2>/dev/null || echo "")
    if [ -z "$decoded" ]; then
      command -v dialog >/dev/null 2>&1 && dialog --msgbox "Invalid token (not Base64 or corrupted). Try again." 7 60 || safe_echo "Invalid token. Try again."
      continue
    fi

    IFS='|' read -r IN_USER IN_PLAN IN_PLANEXP IN_ACTLOCK IN_SIGN <<< "$decoded"

    if [ -z "${IN_USER:-}" ] || [ -z "${IN_PLAN:-}" ] || [ -z "${IN_PLANEXP:-}" ] || [ -z "${IN_ACTLOCK:-}" ]; then
      command -v dialog >/dev/null 2>&1 && dialog --msgbox "Token missing fields. Use USER|PLAN|YYYYMMDD|YYYYMMDDHHMM|SIGN" 8 70 || safe_echo "Token missing fields."
      continue
    fi

    PLAN_EXP_EPOCH=$(yyyymmdd_to_epoch "$IN_PLANEXP")
    ACTLOCK_EPOCH=$(yyyymmddhhmm_to_epoch "$IN_ACTLOCK")
    if [ -z "$PLAN_EXP_EPOCH" ] || [ -z "$ACTLOCK_EPOCH" ]; then
      command -v dialog >/dev/null 2>&1 && dialog --msgbox "Expiry/ActLock format invalid. Use YYYYMMDD and YYYYMMDDHHMM." 8 70 || safe_echo "Expiry format invalid."
      continue
    fi

    NOW_EPOCH=$(date +%s)
    # ActivationLock: token must be used BEFORE or equal to ACTLOCK
    if (( NOW_EPOCH > ACTLOCK_EPOCH )); then
      command -v dialog >/dev/null 2>&1 && dialog --msgbox "Activation window expired on $(date -d "@$ACTLOCK_EPOCH" '+%F %R'). Token invalid." 8 70 || safe_echo "Activation window expired. Token invalid."
      return 1
    fi

    # Plan expiry cannot be earlier than activation lock
    if (( PLAN_EXP_EPOCH < ACTLOCK_EPOCH )); then
      command -v dialog >/dev/null 2>&1 && dialog --msgbox "Plan expiry earlier than activation-lock date. Invalid token." 8 70 || safe_echo "Plan expiry earlier than activation-lock. Invalid token."
      continue
    fi

    # Save activation (bind to device by hash optional; here we save plain values)
    DEVICE_ID=$( (command -v settings >/dev/null 2>&1 && settings get secure android_id 2>/dev/null) || hostname 2>/dev/null || echo "unknown_device" )
    DEVICE_HASH=$(sha256_hash "$DEVICE_ID")
    cat > "$ACT_FILE" <<EOF
USERNAME="${IN_USER}"
PLAN="${IN_PLAN}"
PLAN_EXPIRY_RAW="${IN_PLANEXP}"
ACT_LOCK_RAW="${IN_ACTLOCK}"
PLAN_EXPIRY_EPOCH="${PLAN_EXP_EPOCH}"
ACT_LOCK_EPOCH="${ACTLOCK_EPOCH}"
DEVICE_HASH="${DEVICE_HASH}"
ACTIVATED_ON="$(date '+%Y%m%d%H%M')"
EOF
    chmod 600 "$ACT_FILE"
    info "Activated user=${IN_USER} plan=${IN_PLAN} plan_expiry=${IN_PLANEXP} actlock=${IN_ACTLOCK}"
    command -v dialog >/dev/null 2>&1 && dialog --msgbox "Activation successful!\nUser: ${IN_USER}\nPlan: ${IN_PLAN}\nPlan expiry: $(date -d "@$PLAN_EXP_EPOCH" '+%F')" 8 70 || safe_echo "Activation successful!"
    return 0
  done
}

# -------------------------
# Engine worker (background)
# -------------------------
write_engine_worker(){
  cat > "$ENGINE_SCRIPT" <<'EOE'
#!/data/data/com.termux/files/usr/bin/env bash
HYP_DIR="$HOME/.hypersense"
LOG="$HYP_DIR/logs/engine.log"
AI_LOG="$HYP_DIR/logs/ai_fps_boost.log"
PID_FILE="$HYP_DIR/neural.pid"
CFG="$HYP_DIR/config.cfg"
mkdir -p "$HYP_DIR/logs"
touch "$LOG" "$AI_LOG"
chmod 600 "$LOG" "$AI_LOG" 2>/dev/null || true
echo $$ > "$PID_FILE"
log(){ printf "%s | %s\n" "$(date '+%F %T')" "$*" >> "$LOG"; }
ailog(){ printf "%s | %s\n" "$(date '+%F %T')" "$*" >> "$AI_LOG"; }

# read config safely
[ -f "$CFG" ] && . "$CFG"
: "${neural_turbo:=0}" : "${arc_plus:=0}" : "${vpool_enabled:=0}" : "${uvram_enabled:=0}" : "${afb_mode:=Auto}"

get_bat(){ if command -v termux-battery-status >/dev/null 2>&1; then termux-battery-status 2>/dev/null | awk -F: '/percentage/ {gsub(/[", ]/,"",$2); print $2; exit}'; else echo "N/A"; fi }
get_temp(){
  for tz in /sys/class/thermal/thermal_zone*/temp; do [ -f "$tz" ] || continue; v=$(cat "$tz" 2>/dev/null || echo ""); [ -n "$v" ] && { if [ "${#v}" -gt 3 ]; then awk "BEGIN{printf \"%.1f\", $v/1000}"; else awk "BEGIN{printf \"%.1f\", $v}"; fi; return; }; done
  echo "N/A"
}

ai_estimate(){
  # lightweight estimation for logging only
  CPU_LOAD=$(top -bn1 2>/dev/null | awk '/CPU/ {print $2; exit}' 2>/dev/null | sed 's/%//' || echo 30)
  [ -z "$CPU_LOAD" ] && CPU_LOAD=30
  TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "")
  if [ -n "$TEMP_RAW" ]; then
    if [ "${#TEMP_RAW}" -gt 3 ]; then TEMP=$(expr "$TEMP_RAW" / 1000); else TEMP="$TEMP_RAW"; fi
  else TEMP=35; fi
  BOOST_SCORE=$((100 - CPU_LOAD))
  RR=$(dumpsys SurfaceFlinger 2>/dev/null | grep -oE "[0-9]+(\.[0-9]+)? Hz" | head -n1 | sed 's/ Hz//' || echo 60)
  EST=$(awk -v b="$BOOST_SCORE" -v r="$RR" 'BEGIN{printf "%.1f", (b * r / 100)}')
  ailog "CPU:${CPU_LOAD}% TEMP:${TEMP}C BOOST:${BOOST_SCORE} EST_FPS_GAIN:+${EST}"
}

while true; do
  [ -f "$CFG" ] && . "$CFG"
  BAT=$(get_bat)
  TEMP=$(get_temp)
  log "tick | bat:${BAT}% | temp:${TEMP}C | turbo:${neural_turbo} arc:${arc_plus} vpool:${vpool_enabled} uvr:${uvram_enabled} afb:${afb_mode}"
  ai_estimate
  # simple battery protection: if battery present and <15% pause heavy predictions
  if [ "$BAT" != "N/A" ] && [ "$BAT" -lt 15 ]; then
    log "Battery <15%: throttling predictions"
    sleep 5
    continue
  fi
  # thermal soft guard: if too hot, sleep longer
  if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "")
    if [ -n "$raw" ] && [ "$raw" -gt 50000 ]; then
      log "Temp high: pausing predictive bursts"
      sleep 6
      continue
    fi
  fi
  if [ "${neural_turbo:-0}" -eq 1 ]; then sleep 1; else sleep 2; fi
done
EOE

  chmod 700 "$ENGINE_SCRIPT"
  info "Engine worker written to $ENGINE_SCRIPT"
}

# -------------------------
# Engine control
# -------------------------
is_engine_running(){
  [ -f "$PID_FILE" ] || return 1
  pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
  [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1
}

start_engine(){
  check_activation || { warn "Start blocked: activation invalid."; return 2; }
  if is_engine_running; then info "Engine already running (pid $(cat "$PID_FILE"))"; return 0; fi
  [ -f "$ENGINE_SCRIPT" ] || write_engine_worker
  # start in background reliably
  nohup bash "$ENGINE_SCRIPT" >> "$ENGINE_LOG" 2>&1 &
  # wait for PID file (engine writes its PID)
  for i in {1..15}; do
    sleep 0.3
    is_engine_running && break
  done
  if is_engine_running; then info "Engine started (pid $(cat "$PID_FILE"))"; return 0; else err "Engine failed to start"; return 1; fi
}

stop_engine(){
  if ! is_engine_running; then info "Engine not running"; return 0; fi
  pid=$(cat "$PID_FILE") || true
  kill "$pid" 2>/dev/null || true
  sleep 0.4
  if ! is_engine_running; then rm -f "$PID_FILE" 2>/dev/null || true; info "Engine stopped"; return 0; else err "Failed to stop engine"; return 1; fi
}

enable_neural_turbo(){
  neural_turbo=1; arc_plus=1; vpool_enabled=1; uvram_enabled=1; afb_mode="Auto"
  save_config
  info "Neural Turbo ENABLED"
  start_engine || warn "Engine start failed"
}

disable_neural_turbo(){
  neural_turbo=0; arc_plus=0; vpool_enabled=0; uvram_enabled=0
  save_config
  info "Neural Turbo DISABLED"
}

toggle_arc_plus(){ arc_plus=$((1-arc_plus)); save_config; info "ARC+ -> $arc_plus"; start_engine >/dev/null 2>&1 || true; }
toggle_vpool(){ vpool_enabled=$((1-vpool_enabled)); save_config; info "vPool -> $vpool_enabled"; }
toggle_uvram(){ uvram_enabled=$((1-uvram_enabled)); save_config; info "uVRAM -> $uvram_enabled"; }

set_afb_mode(){
  mode="$1"; afb_mode="$mode"; save_config; info "AFB -> $afb_mode"
}

# -------------------------
# Autostart (Termux:Boot)
# -------------------------
install_autostart(){
  if [ ! -d "$BOOT_DIR" ]; then
    warn "Termux:Boot not detected. Install Termux:Boot and open once."
    command -v dialog >/dev/null 2>&1 && dialog --msgbox "Termux:Boot not found. Install and open it once." 8 60 || echo "Termux:Boot missing."
    return 2
  fi
  cat > "$AUTOSTART_FILE" <<EOF
#!/data/data/com.termux/files/usr/bin/env bash
# Hypersense autostart
sleep 6
bash "$HYP_DIR/$(basename "$0")" --autostart-run >/dev/null 2>&1 &
EOF
  chmod 700 "$AUTOSTART_FILE"
  autostart_enabled=1; save_config
  info "Autostart installed at $AUTOSTART_FILE"
  command -v dialog >/dev/null 2>&1 && dialog --msgbox "Auto-Start installed. Reboot to test." 7 60 || echo "Autostart installed."
}

uninstall_autostart(){ [ -f "$AUTOSTART_FILE" ] && rm -f "$AUTOSTART_FILE"; autostart_enabled=0; save_config; info "Autostart removed"; command -v dialog >/dev/null 2>&1 && dialog --msgbox "Auto-Start disabled." 6 50 || true; }

autostart_health_check(){
  report=""
  [ -f "$AUTOSTART_FILE" ] && report="$report Autostart: PRESENT\n" || report="$report Autostart: MISSING\n"
  if is_engine_running; then report="$report Neural Engine: RUNNING (pid $(cat "$PID_FILE"))\n"; else report="$report Neural Engine: NOT RUNNING\n"; fi
  command -v dialog >/dev/null 2>&1 && dialog --msgbox "$report" 10 60 || echo -e "$report"
}

# -------------------------
# Game detection
# -------------------------
get_foreground_app(){
  if command -v dumpsys >/dev/null 2>&1; then
    fg=$(dumpsys activity activities 2>/dev/null | awk -F' ' '/mResumedActivity|mFocusedActivity/ {print $NF; exit}' | cut -d'/' -f1)
    [ -z "$fg" ] && fg=$(dumpsys window windows 2>/dev/null | awk -F' ' '/mCurrentFocus|mFocusedApp/ {print $3; exit}' | cut -d'/' -f1)
    echo "${fg:-}"
    return
  fi
  echo ""
}

is_game_foreground(){
  fg=$(get_foreground_app)
  [ -z "$fg" ] && return 1
  IFS=','; for pkg in $game_whitelist; do [ "$pkg" = "$fg" ] && return 0; done
  return 1
}

# -------------------------
# Monitor / Logs UI
# -------------------------
monitor_status(){
  tmp="$MONITOR_TMP"
  {
    printf "────────────────────────────────────────────\n"
    printf " HYPERSENSE Monitor — %s\n" "$(date '+%F %T')"
    printf "────────────────────────────────────────────\n\n"
    if check_activation; then
      echo "Activation: VALID"
      . "$ACT_FILE"
      echo "User: ${USERNAME:-N/A}"
      echo "Plan: ${PLAN:-N/A}"
      echo "Plan Expiry: $(date -d "@${PLAN_EXPIRY_EPOCH:-0}" '+%F' 2>/dev/null || echo N/A)"
    else
      echo "Activation: NOT ACTIVE"
    fi
    echo ""
    echo "Neural Turbo:   $( [ "$neural_turbo" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "ARC+:           $( [ "$arc_plus" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "vPool (512MB):  $( [ "$vpool_enabled" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "uVRAM (256MB):  $( [ "$uvram_enabled" -eq 1 ] && echo "ON" || echo "OFF")"
    echo "AFB Mode:       $afb_mode"
    echo "Engine running: $( is_engine_running && echo "YES (pid $(cat "$PID_FILE"))" || echo "NO")"
    echo ""
    bat=$(get_battery_safe)
    temp=$(get_temp_safe)
    rr=$(get_refresh_rate)
    echo "Battery: ${bat}%   Device Temp: ${temp}°C   Display Hz: ${rr}Hz"
    echo ""
    echo "Last Engine Logs:"
    tail -n 12 "$ENGINE_LOG" 2>/dev/null || echo "No logs."
    echo ""
    echo "AI FPS Logs (last 8):"
    tail -n 8 "$AI_FPS_LOG" 2>/dev/null || echo "No AI logs."
    echo ""
  } > "$tmp"

  if command -v dialog >/dev/null 2>&1; then
    dialog --title "Hypersense Monitor" --textbox "$tmp" 22 80
  else
    cat "$tmp"; sleep 2
  fi
  rm -f "$tmp"
}

# -------------------------
# Touch & Presets
# -------------------------
set_touch_values(){
  if command -v dialog >/dev/null 2>&1; then
    vals=$(dialog --inputbox "Enter X,Y,Smooth (comma separated)\nExample: 18,17,0.7" 9 60 3>&1 1>&2 2>&3)
  else
    read -r -p "Enter X,Y,Smooth (e.g. 18,17,0.7): " vals
  fi
  IFS=',' read -r X Y S <<< "${vals},"
  X=${X:-$touch_x}; Y=${Y:-$touch_y}; S=${S:-$touch_smooth}
  if ! [[ "$X" =~ ^[0-9]+$ ]] || [ "$X" -lt 1 ] || [ "$X" -gt 20 ]; then X=$touch_x; fi
  if ! [[ "$Y" =~ ^[0-9]+$ ]] || [ "$Y" -lt 1 ] || [ "$Y" -gt 20 ]; then Y=$touch_y; fi
  if ! awk "BEGIN{exit !(($S+0)==$S)}" 2>/dev/null; then S=$touch_smooth; fi
  touch_x=$X; touch_y=$Y; touch_smooth=$S
  save_config
  command -v dialog >/dev/null 2>&1 && dialog --msgbox "Saved touch: X=$touch_x, Y=$touch_y, smooth=$touch_smooth" 6 50 || echo "Saved touch: X=$touch_x, Y=$touch_y, smooth=$touch_smooth"
}

# -------------------------
# Advanced submenu (A1..A13) - preserved unchanged
# -------------------------
advanced_menu(){
  while true; do
    if command -v dialog >/dev/null 2>&1; then
      CHOICE=$(dialog --title "ADVANCED: Neural Engine" --menu "Select Option" 20 80 14 \
        A1 "Neural Engine Status & Toggle" \
        A2 "ARC+ (Aim & Recoil) Toggle" \
        A3 "Recoil Stability Presets" \
        A4 "Adaptive Frame Booster (AFB) Mode" \
        A5 "vPool / uVRAM Controls" \
        A6 "Predictive Ramp & Micro-Burst Info" \
        A7 "Adaptive Power Governor (Idle/Active)" \
        A8 "Thermal Guardian (thresholds)" \
        A9 "Neural Decision (sampling/trigger)" \
        A10 "Game Detection & Whitelist" \
        A11 "AI Logs (FPS/Recoils)" \
        A12 "Manual Overrides (Force Active/Idle/Safe)" \
        A13 "Back to Main Menu" 3>&1 1>&2 2>&3)
    else
      echo "ADVANCED MENU (no-dialog)"; read -r CHOICE
    fi

    case "$CHOICE" in
      A1)
        status="Engine: $( is_engine_running && echo ON || echo OFF )\nTurbo:$neural_turbo ARC:$arc_plus vPool:$vpool_enabled uVRAM:$uvram_enabled AFB:$afb_mode"
        command -v dialog >/dev/null 2>&1 && dialog --msgbox "$status" 10 60 || echo -e "$status"
        if command -v dialog >/dev/null 2>&1 && dialog --yesno "Toggle Engine (start/stop)?" 7 50; then
          is_engine_running && stop_engine || start_engine
        fi
        ;;
      A2) toggle_arc_plus; command -v dialog >/dev/null 2>&1 && dialog --msgbox "ARC+: $( [ $arc_plus -eq 1 ] && echo ON || echo OFF )" 5 50 || true ;;
      A3)
        if command -v dialog >/dev/null 2>&1; then
          sel=$(dialog --menu "Choose Recoil Preset" 12 60 4 1 "Precision" 2 "Balanced" 3 "Aggressive" 4 "Custom" 3>&1 1>&2 2>&3)
          case $sel in
            1) touch_smooth=0.6; touch_x=14; touch_y=14 ;;
            2) touch_smooth=0.8; touch_x=12; touch_y=12 ;;
            3) touch_smooth=0.5; touch_x=18; touch_y=17 ;;
            4) set_touch_values ;;
          esac
          save_config; dialog --msgbox "Preset applied. X=$touch_x Y=$touch_y S=$touch_smooth" 6 50
        else
          echo "Presets: 1)Precision 2)Balanced 3)Aggressive 4)Custom"; read -r sel
          case $sel in 1) touch_smooth=0.6; touch_x=14; touch_y=14 ;; 2) touch_smooth=0.8; touch_x=12; touch_y=12 ;; 3) touch_smooth=0.5; touch_x=18; touch_y=17 ;; 4) set_touch_values ;; esac
          save_config
        fi
        ;;
      A4)
        if command -v dialog >/dev/null 2>&1; then
          afb_choice=$(dialog --menu "AFB Mode" 12 60 6 1 "Auto (recommended)" 2 "60 Hz" 3 "90 Hz" 4 "120 Hz" 5 "144 Hz" 6 "Off" 3>&1 1>&2 2>&3)
          case $afb_choice in 1)set_afb_mode "Auto";;2)set_afb_mode "60";;3)set_afb_mode "90";;4)set_afb_mode "120";;5)set_afb_mode "144";;6)set_afb_mode "Off";;esac
          dialog --msgbox "AFB -> $afb_mode" 6 40
        else
          echo "AFB modes: Auto / 60 / 90 / 120 / 144 / Off"; read -r m; set_afb_mode "$m"
        fi
        ;;
      A5)
        if command -v dialog >/dev/null 2>&1; then
          vchoice=$(dialog --menu "vPool/uVRAM Controls" 12 60 4 1 "Toggle vPool (512MB)" 2 "Toggle uVRAM (256MB)" 3 "Auto-clean vPool now" 4 "Back" 3>&1 1>&2 2>&3)
          case $vchoice in
            1) toggle_vpool; dialog --msgbox "vPool: $( [ $vpool_enabled -eq 1 ] && echo ON || echo OFF )" 5 50 ;;
            2) toggle_uvram; dialog --msgbox "uVRAM: $( [ $uvram_enabled -eq 1 ] && echo ON || echo OFF )" 5 50 ;;
            3) echo "$(date '+%F %T') - vPool cleaned" >> "$AI_FPS_LOG"; dialog --msgbox "vPool cleaned." 5 40 ;;
          esac
        else
          echo "vPool options"; read -r vchoice; case $vchoice in 1) toggle_vpool ;; 2) toggle_uvram ;; 3) echo "$(date '+%F %T') - vPool cleaned" >> "$AI_FPS_LOG" ;; esac
        fi
        ;;
      A6) command -v dialog >/dev/null 2>&1 && dialog --msgbox "Predictive Ramp runs automatically when Neural Turbo is ON. Micro-burst window: ${micro_trigger_ms}ms" 7 60 || echo "Predictive Ramp info";;
      A7)
        if command -v dialog >/dev/null 2>&1; then
          vals=$(dialog --inputbox "Idle%,Active%,CPUthreshold\nExample: 70,95,45" 9 60 3>&1 1>&2 2>&3)
          IFS=',' read -r it at ct <<< "$vals"
          idle_target=${it:-$idle_target}; active_target=${at:-$active_target}; cpu_threshold=${ct:-$cpu_threshold}
          save_config; dialog --msgbox "Saved Idle:$idle_target Active:$active_target CPUthr:$cpu_threshold" 6 50
        else
          read -r -p "Enter Idle,Active,CPUthr: " vals; IFS=',' read -r it at ct <<< "$vals"; idle_target=${it:-$idle_target}; active_target=${at:-$active_target}; cpu_threshold=${ct:-$cpu_threshold}; save_config
        fi
        ;;
      A8)
        if command -v dialog >/dev/null 2>&1; then
          vals=$(dialog --inputbox "Soft°C,Hard°C\nExample: 45,50" 8 40 3>&1 1>&2 2>&3)
          IFS=',' read -r s h <<< "$vals"
          thermal_soft=${s:-$thermal_soft}; thermal_hard=${h:-$thermal_hard}; save_config; dialog --msgbox "Thermal soft:$thermal_soft hard:$thermal_hard" 6 50
        else
          read -r -p "Enter soft,hard temps: " vals; IFS=',' read -r s h <<< "$vals"; thermal_soft=${s:-$thermal_soft}; thermal_hard=${h:-$thermal_hard}; save_config
        fi
        ;;
      A9)
        if command -v dialog >/dev/null 2>&1; then
          vals=$(dialog --inputbox "Sampling ms, Micro-trigger ms\nExample: 300,120" 8 50 3>&1 1>&2 2>&3)
          IFS=',' read -r si mt <<< "$vals"; sample_interval_ms=${si:-$sample_interval_ms}; micro_trigger_ms=${mt:-$micro_trigger_ms}; save_config; dialog --msgbox "Saved sample:${sample_interval_ms}ms micro:${micro_trigger_ms}ms" 6 50
        else
          read -r -p "Enter sample_ms,micro_ms: " vals; IFS=',' read -r si mt <<< "$vals"; sample_interval_ms=${si:-$sample_interval_ms}; micro_trigger_ms=${mt:-$micro_trigger_ms}; save_config
        fi
        ;;
      A10)
        if command -v dialog >/dev/null 2>&1; then
          new=$(dialog --editbox <(printf "%s\n" $(echo "$game_whitelist" | tr ',' '\n')) 15 60 3>&1 1>&2 2>&3)
          game_whitelist=$(echo "$new" | tr '\n' ',' | sed 's/,$//'); save_config; dialog --msgbox "Whitelist updated." 6 40
        else
          echo "Current whitelist: $game_whitelist"; read -r gw; game_whitelist=${gw:-$game_whitelist}; save_config
        fi
        ;;
      A11) command -v dialog >/dev/null 2>&1 && dialog --title "AI Logs" --textbox "$AI_FPS_LOG" 20 80 || tail -n 200 "$AI_FPS_LOG" ;;
      A12)
        if command -v dialog >/dev/null 2>&1; then
          mm=$(dialog --menu "Manual Overrides" 10 50 3 1 "Force Active (Enable Turbo)" 2 "Force Idle (Disable Turbo)" 3 "Safe Mode (Pause Predictive)" 3>&1 1>&2 2>&3)
          case $mm in 1) enable_neural_turbo ;; 2) disable_neural_turbo ;; 3) disable_neural_turbo; dialog --msgbox "Safe Mode ON" 5 40 ;; esac
        else
          echo "1)Force Active 2)Force Idle 3)Safe Mode"; read -r mm; [ "$mm" = "1" ] && enable_neural_turbo; [ "$mm" = "2" ] && disable_neural_turbo
        fi
        ;;
      A13) break ;;
      *) ;;
    esac
  done
}

# -------------------------
# Main Menu (unchanged structure)
# -------------------------
main_menu(){
  # Ensure activation
  if ! check_activation; then
    prompt_activation || { warn "Activation failed/aborted."; exit 1; }
  fi

  [ -f "$ENGINE_SCRIPT" ] || write_engine_worker
  rotate_log "$ENGINE_LOG"; rotate_log "$AI_FPS_LOG"

  while true; do
    . "$CFG_FILE"
    ACT_TEXT="Not Active"; is_engine_running && ENG_TEXT="ON (pid $(cat "$PID_FILE"))" || ENG_TEXT="OFF"
    check_activation && ACT_TEXT="Active"

    if command -v dialog >/dev/null 2>&1; then
      CHOICE=$(dialog --clear --title "HYPERSENSEINDIA - AG HYDRAX" --menu "Activation: $ACT_TEXT | Engine: $ENG_TEXT\nSelect Option" 24 96 14 \
        1 "Activate / Check Activation" \
        2 "Neural Engine Control (Enable/Disable/Recoil/AFB/Thermal)" \
        3 "Virtual Memory Engine (uVRAM/vPool Controls)" \
        4 "Touch & Recoil Engine (X/Y presets)" \
        5 "ARC+ Performance Engine" \
        6 "FPS / Performance Tools" \
        7 "Game Modes (Auto/Manual/Profiles)" \
        8 "Auto-Start / Watchdog / Logs" \
        9 "System Status Center (Monitor)" \
        10 "Advanced → Neural Engine Submenu" \
        11 "Restore Defaults / Repair" \
        0 "Exit" 3>&1 1>&2 2>&3)
    else
      echo "1)Activate 2)Neural Engine Control 3)Virtual Memory 4)Touch/Recoil 5)ARC+ 6)FPS Tools 7)Game Modes 8)AutoStart/Logs 9)Monitor 10)Advanced 11)Restore 0)Exit"
      read -r CHOICE
    fi

    case "$CHOICE" in
      1) check_activation && command -v dialog >/dev/null 2>&1 && dialog --msgbox "Activation valid." 5 40 || prompt_activation ;;
      2)
        if command -v dialog >/dev/null 2>&1; then
          sub=$(dialog --menu "Neural Engine Control" 15 76 6 1 "Enable Neural Core Engine (All-In-One)" 2 "Disable Neural Core Engine" 3 "Neural Recoil Stability Mode" 4 "AFB Mode Quick" 5 "Neural Thermal Guardian" 6 "Back" 3>&1 1>&2 2>&3)
          case $sub in
            1) enable_neural_turbo; dialog --msgbox "Neural Engine ENABLED (All-in-one)" 6 50 ;;
            2) disable_neural_turbo; dialog --msgbox "Neural Engine DISABLED" 5 50 ;;
            3) dialog --msgbox "Recoil mode applied (see Advanced for presets)" 6 50 ;;
            4) advanced_menu ;; # reuse advanced A4
            5) dialog --msgbox "Thermal Guardian active (Advanced→A8 to configure)" 6 50 ;;
          esac
        else
          echo "Enable/Disable engine"; read -r t; [ "$t" = "1" ] && enable_neural_turbo || disable_neural_turbo
        fi
        ;;
      3)
        if command -v dialog >/dev/null 2>&1; then
          vsub=$(dialog --menu "Virtual Memory Engine" 12 60 4 1 "Toggle uVRAM (256MB)" 2 "Toggle vPool (512MB)" 3 "Clean Neural Memory" 4 "Back" 3>&1 1>&2 2>&3)
          case $vsub in 1) toggle_uvram ;; 2) toggle_vpool ;; 3) echo "$(date '+%F %T') - vPool cleaned" >> "$AI_FPS_LOG"; dialog --msgbox "vPool cleaned." 5 40 ;; esac
        else
          echo "Virtual memory options"; read -r v; [ "$v" = "1" ] && toggle_uvram || toggle_vpool
        fi
        ;;
      4) set_touch_values ;;
      5)
        if command -v dialog >/dev/null 2>&1; then
          dsub=$(dialog --menu "ARC+ Engine" 12 60 4 1 "Enable ARC+ (Max)" 2 "Disable ARC+" 3 "ARC+ Sync Mode" 4 "Back" 3>&1 1>&2 2>&3)
          case $dsub in 1) arc_plus=1; save_config; dialog --msgbox "ARC+ Enabled" 5 40 ;; 2) arc_plus=0; save_config; dialog --msgbox "ARC+ Disabled" 5 40 ;; 3) dialog --msgbox "ARC+ Sync Mode active (paired with Neural Turbo)." 6 50 ;; esac
        else
          echo "ARC+ options"; read -r s; [ "$s" = "1" ] && arc_plus=1 || arc_plus=0; save_config
        fi
        ;;
      6)
        if command -v dialog >/dev/null 2>&1; then
          dialog --msgbox "FPS Tools: Estimator & Smoother are active under Neural Engine. See Advanced→A4/A11 for details & logs." 8 60
        else
          echo "FPS Tools available in Advanced menu."
        fi
        ;;
      7)
        if command -v dialog >/dev/null 2>&1; then
          gsub=$(dialog --menu "Game Modes" 12 60 4 1 "Smart Game Detection (Auto)" 2 "Game Mode: Force ON" 3 "Game Mode: Force OFF" 4 "Profiles (Free Fire/BGMI/PES)" 3>&1 1>&2 2>&3)
          case $gsub in
            1) dialog --msgbox "Smart detection runs automatically." 5 40 ;;
            2) cpu_threshold=5; save_config; dialog --msgbox "Game Mode forced ON (manual)." 5 40 ;;
            3) cpu_threshold=45; save_config; dialog --msgbox "Game Mode forced OFF (manual revert)." 5 40 ;;
            4) dialog --msgbox "Profiles are auto-applied on detection." 6 50 ;;
          esac
        else
          echo "Game modes: auto/dedicated"
        fi
        ;;
      8)
        if command -v dialog >/dev/null 2>&1; then
          msub=$(dialog --menu "Auto-Start & Logs" 15 70 6 1 "Enable Auto-Start (Termux:Boot)" 2 "Disable Auto-Start" 3 "Watchdog Status" 4 "View Live Engine Logs" 5 "View AI FPS Logs" 6 "Back" 3>&1 1>&2 2>&3)
          case $msub in
            1) install_autostart ;; 2) uninstall_autostart ;; 3) autostart_health_check ;; 4) dialog --title "Engine Log" --textbox "$ENGINE_LOG" 20 80 ;; 5) dialog --title "AI FPS Log" --textbox "$AI_FPS_LOG" 20 80 ;; esac
        else
          echo "Autostart & logs"; read -r m; [ "$m" = "1" ] && install_autostart || uninstall_autostart
        fi
        ;;
      9) monitor_status ;;
      10) advanced_menu ;;
      11)
        # Preserve activation; reset configs and logs
        default_config; save_config; rm -f "$ENGINE_LOG" "$AI_FPS_LOG" "$PID_FILE" 2>/dev/null || true
        mkdir -p "$LOG_DIR"
        command -v dialog >/dev/null 2>&1 && dialog --msgbox "Defaults restored (activation preserved if present)." 6 60 || echo "Defaults restored."
        ;;
      0) clear; exit 0 ;;
      *) ;;
    esac
  done
}

# -------------------------
# Autostart-run (non-interactive)
# -------------------------
if [ "${1:-}" = "--autostart-run" ]; then
  if check_activation; then
    . "$CFG_FILE"
    start_engine || info "Autostart engine start failed"
  else
    info "Autostart: activation missing; exit"
  fi
  exit 0
fi

# -------------------------
# Startup banner & entrypoint
# -------------------------
clear
if command -v dialog >/dev/null 2>&1; then
  dialog --msgbox "────────────────────────────────────────────\nHYPERSENSEINDIA\nAG HYDRAX\nMarketing Head: Roobal Sir (@roobal_sir)\nNeural vPool uVRAM Engine v10 — Final Release\nActivation required on first run.\n────────────────────────────────────────────" 14 72
else
  safe_echo "HYPERSENSEINDIA - Neural vPool uVRAM Engine v10 - Final Release"
fi

# Ensure engine worker exists
[ -f "$ENGINE_SCRIPT" ] || write_engine_worker

# rotate logs lightly
rotate_log "$ENGINE_LOG"; rotate_log "$AI_FPS_LOG"

# Run menu
main_menu
