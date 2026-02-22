#!/bin/bash

check_drive_strict() {
    DRIVE=$1
    FAIL=0
    
    echo "Running ZERO TOLERANCE check on $DRIVE..."

    # 1. Check Overall Health
    HEALTH=$(smartctl -H "$DRIVE" | grep -i "test result" | awk '{print $6}')
    # Some drives output "health status: passed" or similar, catch both
    if [[ "$HEALTH" != "PASSED" && "$HEALTH" != "OK" ]]; then
        # Check if the output is just missing (common on some USB bridges)
        FULL_HEALTH=$(smartctl -H "$DRIVE")
        if [[ $FULL_HEALTH != *"PASSED"* && $FULL_HEALTH != *"OK"* ]]; then
             echo -e "\e[41m\e[97m CRITICAL: Drive Reported HEALTH FAILURE \e[0m"
             FAIL=1
        fi
    fi

    # Detect Drive Type
    TYPE=$(smartctl -i "$DRIVE" | grep -q "NVMe" && echo "nvme" || echo "sata")

    if [ "$TYPE" == "sata" ]; then
        # --- SATA SPECIFIC CHECKS ---
        
        # 1. Reallocated / Pending / Uncorrectable
        BAD_SECTORS=$(smartctl -A "$DRIVE" | awk '$1=="5" || $1=="197" || $1=="198" {sum+=$10} END {print sum+0}')
        # Handle case where awk returns empty (rare, but safe)
        if [[ -z "$BAD_SECTORS" ]]; then BAD_SECTORS=0; fi

        if [ "$BAD_SECTORS" -gt 0 ]; then
            echo -e "\e[41m\e[97m FAIL: Found $BAD_SECTORS Bad/Pending Sectors (SATA) \e[0m"
            FAIL=1
        fi

        # 2. ATA Error Log (MOVED INSIDE SATA BLOCK)
        # We try to grab the number. If grep finds nothing, it returns empty string.
        LOG_COUNT=$(smartctl -l error "$DRIVE" | grep "ATA Error Count" | awk '{print $4}')
        
        # THE FIX: If variable is empty, default to 0 to prevent script crash
        if [[ -z "$LOG_COUNT" ]]; then 
            LOG_COUNT=0
        fi

        if [ "$LOG_COUNT" -gt 0 ]; then
             echo -e "\e[41m\e[97m FAIL: Drive has $LOG_COUNT recorded ATA errors in history \e[0m"
             FAIL=1
        fi

    elif [ "$TYPE" == "nvme" ]; then
        # --- NVMe SPECIFIC CHECKS ---
        
        MEDIA_ERRORS=$(smartctl -A "$DRIVE" | grep "Media and Data Integrity Errors" | awk '{print $NF}')
        CRITICAL_WARN=$(smartctl -A "$DRIVE" | grep "Critical Warning" | awk '{print $NF}')
        
        # Safety defaults
        if [[ -z "$MEDIA_ERRORS" ]]; then MEDIA_ERRORS=0; fi
        if [[ -z "$CRITICAL_WARN" ]]; then CRITICAL_WARN=0; fi

        if [ "$MEDIA_ERRORS" != "0" ]; then
            echo -e "\e[41m\e[97m FAIL: NVMe Media Errors Detected: $MEDIA_ERRORS \e[0m"
            FAIL=1
        fi
        
        if [ "$CRITICAL_WARN" != "0x00" ] && [ "$CRITICAL_WARN" != "0" ]; then
             echo -e "\e[41m\e[97m FAIL: NVMe Critical Warning Flag Set: $CRITICAL_WARN \e[0m"
             FAIL=1
        fi
    fi

    # FINAL VERDICT
    if [ "$FAIL" -eq 1 ]; then
        echo ""
        echo -e "\e[5m\e[41m\e[97m  !!! DRIVE FAILED STRICT INSPECTION !!!  \e[0m"
        echo -e "\a" 
        return 1
    else
        echo -e "\e[42m\e[97m  DRIVE PERFECT (Strict Check Passed)  \e[0m"
        return 0
    fi
}

run_stress_test() {
    DURATION="30m"
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    echo "Starting 30-Minute Burn-in (CPU + MEMORY + IO)..."
    
    # 1. Start Logging Temps in the background
    # We poll every 30s. If temp > 90C, we flag it.
    (
        for i in {1..60}; do
            # Get max temp from sensors (adjust 'Package id 0' for your specific CPU)
            TEMP=$(sensors | grep "Package id 0" | awk '{print $4}' | tr -d '+°C' | awk -F. '{print $1}')
            
            if [ ! -z "$TEMP" ] && [ "$TEMP" -gt 90 ]; then
                echo "CRITICAL: OVERHEATING DETECTED ($TEMP°C)" > /tmp/thermal_fail
            fi
            sleep 30
        done
    ) &
    TEMP_PID=$!

    # 2. Run the Stress Test
    # --cpu 0: Use all cores
    # --vm 2: Spin up 2 memory stressors (finds bad RAM faster than CPU alone)
    # --io 2: Stress the I/O scheduler
    stress-ng --cpu 0 --vm 2 --io 2 --timeout $DURATION --metrics-brief

    # 3. Analyze Results
    kill $TEMP_PID 2>/dev/null
    
    if [ -f /tmp/thermal_fail ]; then
        echo -e "\e[41m\e[97m FAIL: Unit Overheated (>90C) during stress test! \e[0m"
        echo -e "\e[41m\e[97m Repaste Thermal Compound or Replace Fan. \e[0m"
        return 1
    elif [ $? -eq 0 ]; then
        echo -e "\e[42m\e[97m PASS: System survived 30m stress test stable. \e[0m"
        return 0
    else
        echo -e "\e[41m\e[97m FAIL: System crashed or stress-ng detected error! \e[0m"
        return 1
    fi
}

safe_wipe() {
    TARGET_DRIVE=$1
    
    # 1. Sanity Check: Does the block device exist?
    if [ ! -b "$TARGET_DRIVE" ]; then
        echo -e "\e[41m\e[97m ERROR: Device $TARGET_DRIVE not found. \e[0m"
        return 1
    fi

    # 2. Get the clear kernel name (e.g., "sda" from "/dev/sda")
    KNAME=$(basename "$TARGET_DRIVE")

    # 3. CHECK REMOVABLE STATUS
    # /sys/block/sda/removable contains '1' for USB/Removable, '0' for Internal/Fixed
    IS_REMOVABLE=$(cat /sys/block/$KNAME/removable)

    # 4. CHECK IF MOUNTED (Double safety)
    # Ensure we aren't trying to wipe a drive that has mounted partitions (like our USB source)
    IS_MOUNTED=$(lsblk -n -o MOUNTPOINT "$TARGET_DRIVE" | grep -v "^$")

    if [ "$IS_REMOVABLE" -eq 1 ]; then
        echo -e "\e[5m\e[41m\e[97m  DANGER: $TARGET_DRIVE IS FLAGGED AS REMOVABLE (USB?)  \e[0m"
        echo -e "\e[41m\e[97m  ABORTING WIPE TO PROTECT VENTOY DRIVE  \e[0m"
        # Beep aggressively
        echo -e "\a"
        sleep 1
        echo -e "\a"
        exit 1
    elif [ ! -z "$IS_MOUNTED" ]; then
        echo -e "\e[41m\e[97m  ERROR: $TARGET_DRIVE has mounted partitions ($IS_MOUNTED). Unmount first.  \e[0m"
        exit 1
    else
        echo "Safety Checks Passed: $TARGET_DRIVE is Internal (Fixed)."
        # 1. Wipe Children First (Partitions)
        # We ask lsblk for all children of the target, ensuring we don't error if none exist.
        for part in $(lsblk --list --noheadings --output NAME "$TARGET_DRIVE" | grep -v "^$(basename "$TARGET_DRIVE")$"); do
            # /dev/ is needed because lsblk returns just names (sda1)
            echo "Erasing partition ${part}..."
            wipefs --all --force "/dev/$part" 2>/dev/null
        done
        
        # Wipes filesystem signatures
        wipefs --all --force "$TARGET_DRIVE"
        
        # Optional: Since these are SSDs, force a discard to zero the cells (takes 2-5 seconds)
        # This is better for resale than just wipefs.
        echo "Trimming blocks (Secure Erase)..."
        blkdiscard "$TARGET_DRIVE" 2>/dev/null || echo "blkdiscard failed (not supported?), skipping."
        
        # Re-read partition table so kernel knows it's empty
        partprobe "$TARGET_DRIVE"
        echo -e "\e[42m\e[97m  DRIVE WIPED SUCCESSFULLY  \e[0m"
    fi
}

echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "  WARNING: YOU ARE ABOUT TO ERASE ALL DATA !! "
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "--------------------------------------------------"

read -p "Are you sure you want to proceed? (type YESIAMSURE): " confirm

if [[ $confirm != "YESIAMSURE" ]]; then
    echo "Aborting. No changes made."
    exit 1
fi

echo "Proceeding with drive erasures..."

for drive in $(lsblk -dnpo NAME,TRAN,TYPE | awk '$2 != "usb" && $3 == "disk" {print $1}'); do
	echo "erasing ${drive}..."
	safe_wipe ${drive}
	check_drive_strict ${drive} || exit 1
done

run_stress_test
