#!/bin/zsh

# Use Zsh on macOS to support associative arrays and better scripting
set -e

echo "Starting Play Store screenshot generation..."
echo "Capturing the three required Play Store device classes: phone, 7-inch tablet, and 10-inch tablet."

TEST_TARGET="${TEST_TARGET:-integration_test/store_listing_screenshots_test.dart}"

run_optional_adb_command() {
  "$@" >/dev/null 2>&1 &
  local pid=$!
  local elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    if [ $elapsed -ge 10 ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "  Skipped optional adb command after 10s: $*"
      return 0
    fi

    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid" 2>/dev/null || true
}

# Clean up any existing screenshots
echo "Cleaning up existing screenshots..."
rm -rf screenshots/
mkdir -p screenshots/

# Map Play Store device classes to emulator IDs and screenshot directories.
typeset -A EMULATOR_IDS
typeset -A OUTPUT_DIRS
typeset -A DISPLAY_NAMES

EMULATOR_IDS=(
  "phone" "Small_Phone"
  "tablet_7" "Nexus_7"
  "tablet_10" "Pixel_Tablet"
)

OUTPUT_DIRS=(
  "phone" "phone"
  "tablet_7" "tablet_7"
  "tablet_10" "tablet_10"
)

DISPLAY_NAMES=(
  "phone" "Phone"
  "tablet_7" "7-inch tablet"
  "tablet_10" "10-inch tablet"
)

# Order to process them
# If an argument is provided, only process that device class or emulator ID.
if [ -n "$1" ]; then
  ORDER=()
  if [ -n "${EMULATOR_IDS[$1]}" ]; then
    ORDER=("$1")
  else
    for key in phone tablet_7 tablet_10; do
      if [ "${EMULATOR_IDS[$key]}" = "$1" ]; then
        ORDER=("$key")
        break
      fi
    done
  fi

  if [ ${#ORDER[@]} -eq 0 ]; then
    echo "Unknown device class or emulator ID: $1"
    echo "Use one of: phone, tablet_7, tablet_10, Small_Phone, Nexus_7, Pixel_Tablet"
    exit 1
  fi
else
  ORDER=("phone" "tablet_7" "tablet_10")
fi

echo "Using screenshot integration target: $TEST_TARGET"

for device_class in "${ORDER[@]}"; do
  emu_id="${EMULATOR_IDS[$device_class]}"
  dir_name="${OUTPUT_DIRS[$device_class]}"
  display_name="${DISPLAY_NAMES[$device_class]}"
  output_dir="screenshots/$dir_name"
  mkdir -p "$output_dir"
  
  echo "---------------------------------------------------"
  echo "Processing Play Store $display_name screenshots with $emu_id -> $output_dir"
  echo "---------------------------------------------------"

  # 1. Launch the emulator
  echo "Launching emulator: $emu_id..."
  flutter emulators --launch "$emu_id"

  # 2. Wait for the launched virtual device to be detected by ADB.
  echo "Waiting for virtual device $emu_id to appear in ADB..."
  device_id=""
  count=0
  while [ -z "$device_id" ]; do
    sleep 5
    count=$((count + 5))

    for serial in ${(f)"$(adb devices | awk '/^emulator-[0-9]+[[:space:]]+device$/ {print $1}')"}; do
      avd_name=$(adb -s "$serial" emu avd name 2>/dev/null | head -n 1 | tr -d '\r')
      if [ "$avd_name" = "$emu_id" ]; then
        device_id="$serial"
        break
      fi
    done

    echo "  Still waiting for $emu_id... (${count}s)"
    
    if [ $count -gt 120 ]; then
      echo "Timeout waiting for virtual device $emu_id in ADB."
      exit 1
    fi
  done

  echo "Device $device_id detected. Waiting for boot to complete..."
  
  boot_completed=""
  count=0
  while [ "$boot_completed" != "1" ]; do
    sleep 5
    count=$((count + 5))
    boot_completed=$(adb -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
    echo "  Still booting... (status: ${boot_completed:-0})"
    
    if [ $count -gt 180 ]; then
      echo "Timeout waiting for $emu_id to boot."
      exit 1
    fi
  done

  echo "Boot complete! Giving system UI 20 seconds to fully settle..."
  sleep 20

  # 4. Clean status bar
  echo "Cleaning status bar..."
  run_optional_adb_command adb -s "$device_id" shell settings put global airplane_mode_on 1
  run_optional_adb_command adb -s "$device_id" shell cmd statusbar disable-for-setup 1
  run_optional_adb_command adb -s "$device_id" shell am broadcast -a com.android.systemui.demo -e command enter
  run_optional_adb_command adb -s "$device_id" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
  run_optional_adb_command adb -s "$device_id" shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e level 4 -e datatype none
  run_optional_adb_command adb -s "$device_id" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200

  # 5. Run the integration test
  echo "Running integration tests on $device_id..."
  export SCREENSHOT_DIR="$output_dir"
  
  flutter drive \
    -d "$device_id" \
    --driver=test_driver/screenshot_driver.dart \
    --target="$TEST_TARGET"

  # 6. Shut down the emulator
  echo "Shutting down emulator..."
  adb -s "$device_id" emu kill
  
  # Wait for it to disappear from ADB
  echo "Waiting for device to disappear..."
  while adb devices | grep -q "$device_id"; do
    sleep 2
  done
  echo "Device $device_id is gone."
  
  sleep 5
done

echo "✅ Play Store screenshots generated successfully in the 'screenshots' directory!"
