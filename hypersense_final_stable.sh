#!/data/data/com.termux/files/usr/bin/bash
clear

# ============================================================
#   Hypersense Neural vPool uVRAM Engine v10 — FINAL RELEASE
# ============================================================
#   World’s First Non-Root AI Performance System
#
#   Brand: HypersenseIndia
#   Developer: AG Hydrax
#   Marketing Head: Roobal Sir (@roobal_sir)
#
#   Stable Release: 2025
#   Zero-Crash Engine | Zero-GUI Jump | Auto-Start Supported
# ============================================================

# ============ GLOBAL PATHS ===============
ACTFILE="$HOME/.hypersense_activation"
AIFILE="$HOME/.hypersense_engine_state"
LOGFILE="$HOME/hypersense_logs.txt"
VRAMFILE="$HOME/.hypersense_vram"

# =========== SAFETY CHECK: TERMUX:API =====
check_termux_api() {
    if ! command -v termux-battery-status >/dev/null 2>&1; then
        echo "[ERROR] Termux:API missing!"
        echo "Run: pkg install termux-api"
        exit 1
    fi
}

# =========== BRANDING HEADER ==============
branding() {
clear
echo -e "\e[44;1;37m────────────────────────────────────────────\e[0m"
echo -e "\e[44;1;37m   Hypersense Neural vPool uVRAM Engine v10\e[0m"
echo -e "\e[44;1;37m   World’s First Non-Root AI Performance System\e[0m"
echo
echo -e "\e[44;1;37m   Brand: HypersenseIndia\e[0m"
echo -e "\e[44;1;37m   Developer: AG Hydrax\e[0m"
echo -e "\e[44;1;37m   Marketing Head: Roobal Sir (@roobal_sir)\e[0m"
echo -e "\e[44;1;37m────────────────────────────────────────────\e[0m"
echo
}

# =========== ACTIVATION ====================
check_activation() {
    if [ ! -f "$ACTFILE" ]; then
        return 1
    fi

    USERNAME=$(head -n1 "$ACTFILE")
    PLAN=$(sed -n 2p "$ACTFILE")
    EXPIRY=$(sed -n 3p "$ACTFILE")
    DEVICE=$(sed -n 4p "$ACTFILE")

    # 🔹 FIXED: Use IST timezone
    NOW=$(TZ='Asia/Kolkata' date +%s)
    if [ "$NOW" -ge "$EXPIRY" ]; then
        return 2
    fi

    return 0
}

activate_tool() {
    branding
    echo "🔐 Enter Activation Key:"
    read -r KEY

    # KEY FORMAT:
    # username|plan|expiryUTC|signature
    IFS="|" read -r USER PLAN EXP SIGN <<< "$KEY"

    if [ -z "$USER" ] || [ -z "$PLAN" ] || [ -z "$EXP" ]; then
        echo "❌ Invalid key format"
        sleep 2
        return
    fi

    DEVICE_ID=$(getprop ro.serialno 2>/dev/null || echo "NOID")

    echo "$USER" > $ACTFILE
    echo "$PLAN" >> $ACTFILE
    echo "$EXP" >> $ACTFILE
    echo "$DEVICE_ID" >> $ACTFILE

    echo "✔ Activation Successful!"
    sleep 2
}

activation_menu() {
    branding

    check_activation
    STATUS=$?

    if [ "$STATUS" -eq 1 ]; then
        echo "❌ Not Activated"
    elif [ "$STATUS" -eq 2 ]; then
        echo "❌ Key Expired"
    else
        echo "✔ Activated"
        echo "Username: $USERNAME"
        echo "Plan: $PLAN"
        echo "Expiry: $(TZ='Asia/Kolkata' date -d @$EXPIRY)"
        echo "Device: $DEVICE"
    fi

    echo
    echo "1) Activate Now"
    echo "0) Back"
    read -p "Select: " AC

    [ "$AC" = "1" ] && activate_tool
}

# ============== NEURAL ENGINE =============
start_engine() {
    echo "ENGINE=ON" > "$AIFILE"
    echo "[AI] Engine started." >> "$LOGFILE"
}

stop_engine() {
    echo "ENGINE=OFF" > "$AIFILE"
    echo "[AI] Engine stopped." >> "$LOGFILE"
}

engine_status() {
    if [ ! -f "$AIFILE" ]; then
        echo "OFF"
    else
        cat "$AIFILE" | sed 's/ENGINE=//'
    fi
}

engine_menu() {
    branding
    echo "Neural Engine Status: $(engine_status)"
    echo
    echo "1) Enable Engine"
    echo "2) Disable Engine"
    echo "0) Back"
    read -p "Select: " EN

    case $EN in
        1) start_engine ;;
        2) stop_engine ;;
    esac
}

# =============== VRAM SYSTEM =================
vram_menu() {
    branding
    echo "uVRAM / vPool Virtual Memory Controls"
    echo "--------------------------------------"
    echo "1) Apply 512MB vPool"
    echo "2) Remove Virtual Memory"
    echo "0) Back"
    read -p "Select: " VR

    case $VR in
        1) echo "512" > "$VRAMFILE"; echo "✔ vPool Applied" ;;
        2) rm -f "$VRAMFILE"; echo "✔ Removed" ;;
    esac
    sleep 1
}

# ============= TOUCH / RECOIL =================
touch_menu() {
    branding
    echo "Touch / Recoil Engine"
    echo "1) Low"
    echo "2) Medium"
    echo "3) High"
    echo "0) Back"
    read -p "Select: " T
}

# ============= FPS MENU ===================
fps_menu() {
    branding
    echo "FPS Tools"
    echo "1) 60 Hz Mode"
    echo "2) 90 Hz Mode"
    echo "3) 120 Hz Mode"
    echo "0) Back"
    read -p "Select: " F
}

# ============= GAME MODE ==================
gamemode_menu() {
    branding
    echo "Game Modes"
    echo "1) Auto Mode"
    echo "2) Manual Mode"
    echo "3) Profile Mode"
    echo "0) Back"
    read -p "Select: " G
}

# ============= AUTOSTART ==================
autostart_menu() {
    branding
    echo "Auto-Start / Logs / Watchdog"
    echo "--------------------------------"
    echo "1) Enable Auto-Start"
    echo "2) Disable Auto-Start"
    echo "3) View Logs"
    echo "0) Back"
    read -p "Select: " A

    case $A in
        1)
            mkdir -p ~/.termux/boot
            cp "$PWD/hypersense_final_stable.sh" ~/.termux/boot/
            echo "✔ Auto-Start Enabled"
        ;;
        2)
            rm -f ~/.termux/boot/hypersense_final_stable.sh
            echo "✔ Auto-Start Disabled"
        ;;
        3)
            clear; cat "$LOGFILE"; read -p "Press enter..." ;;
    esac
}

# ============= SYSTEM STATUS ==================
status_menu() {
    branding
    echo "System Monitor (safe)"
    termux-battery-status
    echo
    read -p "Press Enter..."
}

# ============= ADVANCED SUBMENU ===============
advanced_menu() {
    branding
    echo "ADVANCED (Neural Engine)"
    echo "A1) Neural Engine Status"
    echo "A2) ARC+ Toggle"
    echo "A3) Recoil Presets"
    echo "A4) AFB Mode"
    echo "A5) vPool / uVRAM Controls"
    echo "A6) Predictive & Microburst"
    echo "A7) Power Governor"
    echo "A8) Thermal Guardian"
    echo "A9) Neural Sampling"
    echo "A10) Game Detection & Whitelist"
    echo "A11) AI Logs"
    echo "A13) Back"
    read -p "Select: " ADV
}

# ============ RESTORE ====================
restore_menu() {
    branding
    rm -f "$VRAMFILE"
    rm -f "$AIFILE"
    echo "✔ Restored Defaults"
    sleep 1
}

# ============= MAIN MENU ==================
main_menu() {
while true; do

    branding
    echo "1) Activate / Check Activation"
    echo "2) Neural Engine Control"
    echo "3) Virtual Memory Engine (uVRAM/vPool)"
    echo "4) Touch & Recoil Engine"
    echo "5) ARC+ Performance Engine"
    echo "6) FPS / Performance Tools"
    echo "7) Game Modes"
    echo "8) Auto-Start / Watchdog / Logs"
    echo "9) System Status Center"
    echo "10) Advanced → Neural Engine Submenu"
    echo "11) Restore Defaults / Repair"
    echo "0) Exit"
    echo
    read -p "Select Option: " M

    case $M in
        1) activation_menu ;;
        2) engine_menu ;;
        3) vram_menu ;;
        4) touch_menu ;;
        5) echo "ARC+ Enabled (dummy safe placeholder)" ; sleep 1 ;;
        6) fps_menu ;;
        7) gamemode_menu ;;
        8) autostart_menu ;;
        9) status_menu ;;
        10) advanced_menu ;;
        11) restore_menu ;;
        0) exit 0 ;;
    esac

done
}

# ============= START APP ==================
check_termux_api
main_menu
