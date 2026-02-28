#!/bin/zsh

# Use Zsh on macOS to support associative arrays and better scripting
echo "Starting automated screenshot generation..."

# Clean up any existing screenshots
echo "Cleaning up existing screenshots..."
rm -rf screenshots/
mkdir -p screenshots/

# Map of Emulator IDs to their screenshot directory
typeset -A EMULATORS
EMULATORS=(
  "Small_Phone" "phone"
  "Nexus_7" "tablet_7"
  "Pixel_Tablet" "tablet_10"
)

# Order to process them
ORDER=("Small_Phone" "Nexus_7" "Pixel_Tablet")

for emu_id in "${ORDER[@]}"; do
  output_dir="screenshots/${EMULATORS[$emu_id]}"
  
  echo "---------------------------------------------------"
  echo "Processing $emu_id -> $output_dir"
  echo "---------------------------------------------------"

  # 1. Launch the emulator
  echo "Launching emulator: $emu_id..."
  flutter emulators --launch "$emu_id"

  # 2. Wait for the emulator to be detected by ADB
  echo "Waiting for device to appear in ADB..."
  # We look for the first emulator ID (usually emulator-5554)
  device_id=""
  count=0
  while [ -z "$device_id" ]; do
    sleep 5
    count=$((count + 5))
    echo "  Still waiting for ADB... (${count}s)"
    device_id=$(adb devices | grep 'emulator' | grep 'device$' | awk '{print $1}' | head -n 1)
  done

  echo "Device $device_id detected. Waiting for boot to complete..."
  
  # 3. Wait for the Android system to report boot_completed
  # This is much more reliable than a simple sleep
  boot_completed=""
  while [ "$boot_completed" != "1" ]; do
    sleep 5
    boot_completed=$(adb -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
    echo "  Still booting... (status: ${boot_completed:-0})"
  done

  echo "Boot complete! Giving system UI 20 seconds to fully settle..."
  sleep 20

  # 4. Clean status bar
  echo "Cleaning status bar..."
  adb -s "$device_id" shell settings put global airplane_mode_on 1 2>/dev/null
  adb -s "$device_id" shell am broadcast -a android.intent.action.AIRPLANE_MODE 2>/dev/null
  adb -s "$device_id" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false 2>/dev/null
  adb -s "$device_id" shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e level 4 -e datatype none 2>/dev/null
  adb -s "$device_id" shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200 2>/dev/null

  # 5. Run the integration test
  echo "Running integration tests on $device_id..."
  export SCREENSHOT_DIR="$output_dir"
  
  # Use the specific device ID we found to ensure flutter drive picks the right one
  flutter drive \
    -d "$device_id" \
    --driver=test_driver/screenshot_driver.dart \
    --target=integration_test/app_test.dart

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

echo "✅ All screenshots generated successfully in the 'screenshots' directory!"
