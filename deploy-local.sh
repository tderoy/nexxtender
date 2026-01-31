#!/bin/bash

### functions
function do_exit {
  local exit_code=$1
  local msg=$2
  if [ "$do_debug" = true ]; then
    set -x
  fi
  if [ "$exit_code" -ne 0 ]; then
    echo "ERROR: $msg"
  fi
  exit "$exit_code"
}

function do_it() {
  local do_clean do_compile do_upload do_flash_usb do_logs do_debug
  do_clean=$1
  do_compile=$2
  do_upload=$3
  do_flash_usb=$4
  do_logs=$5

  # Execute commands based on flags
  echo "=== ESPHome Nexxtender Local Deployment ==="
  echo "Configuration file: ${yamlFile}"
  echo "Target device: ${device}"
  echo ""

  if [ "$do_clean" = true ]; then
    echo ">>> Cleaning build..."
    if ! esphome clean "${yamlFile}"; then
      do_exit 1 "Clean command failed"
    fi
    echo "✓ Clean completed"
    echo ""
  fi

  if [ "$do_compile" = true ]; then
    echo ">>> Compiling firmware..."
    if ! esphome compile "${yamlFile}"; then
      do_exit 1 "Compilation failed"
    fi
    echo "✓ Compilation completed"
    echo ""
  fi

  if [ "$do_upload" = true ]; then
    echo ">>> Uploading firmware via OTA..."
    if ! esphome upload "${yamlFile}" --device "${device}"; then
      do_exit 1 "Upload failed"
    fi
    echo "✓ Upload completed"
    echo ""
  fi

  if [ "$do_flash_usb" = true ]; then
    echo ">>> Flashing firmware via USB..."

    # Auto-detect USB serial port on Mac
    echo "Detecting USB serial port..."
    usb_port=$(ls /dev/cu.usbserial-* /dev/cu.SLAB_USBtoUART /dev/cu.wchusbserial* 2>/dev/null | head -n 1)

    if [ -z "$usb_port" ]; then
      echo "No USB serial port detected. Please connect your ESP32 device."
      echo "Available ports:"
      ls /dev/cu.* 2>/dev/null | grep -E "(usb|serial|SLAB|wch)" || echo "  No USB ports found"
      read -p "Enter port manually (e.g., /dev/cu.usbserial-0001) or press Enter to cancel: " manual_port
      if [ -n "$manual_port" ]; then
        usb_port="$manual_port"
      else
        do_exit 1 "USB flash cancelled - no port specified"
      fi
    fi

    echo "Using port: $usb_port"
    echo ""

    if ! esphome run "${yamlFile}" --device "$usb_port"; then
      do_exit 1 "USB flash failed"
    fi
    echo "✓ USB flash completed"
    echo ""
  fi

  if [ "$do_logs" = true ]; then
    echo ">>> Displaying logs (Ctrl+C to quit)..."
    export PYTHONIOENCODING=utf-8
    truncate -s 0 "${logFile}"

    # If we just flashed via USB, use the USB port for logs
    if [ "$do_flash_usb" = true ] && [ -n "$usb_port" ]; then
      esphome logs "${yamlFile}" --device "$usb_port" | tee -a "${logFile}"
    else
      esphome logs "${yamlFile}" --device "${device}" | tee -a "${logFile}"
    fi
  fi

  echo ""
  echo "=== Completed ==="
}

## ESPHome Nexxtender Local Deployment Script
## Usage: sh deploy-local.sh [config_file] [-C] [-c] [-u] [-f] [-l] [-d]
# config_file : YAML configuration file (default: nexxtender.local.yaml)
#               Can be: nexxtender.local.yaml or nexxtender.s3.local.yaml
# -C : clean (clean build directory)
# -c : compile only
# -u : upload (via OTA to nexxtender.local)
# -f : flash via USB (serial port auto-detected)
# -l : logs (display real-time logs)
# -d : debug mode
# Without options: compile + upload + logs

# Default values
yamlFile="nexxtender.local.yaml"
device="nexxtender.local"
logFile="nexxtender.log"

# Check if first argument is a config file
if [ $# -gt 0 ] && [ "${1:0:1}" != "-" ]; then
  yamlFile="$1"
  shift  # Remove the first argument so getopts can process the rest

  # Validate that the file exists
  if [ ! -f "$yamlFile" ]; then
    echo "ERROR: Configuration file '$yamlFile' not found"
    echo ""
    echo "Available configuration files:"
    ls -1 nexxtender*.yaml 2>/dev/null || echo "  No nexxtender*.yaml files found"
    exit 1
  fi

fi

# Default flags
do_clean=false
do_compile=false
do_upload=false
do_flash_usb=false
do_logs=false
has_options=false
do_debug=false

# Parse options
while getopts "Cculfd" opt; do
  has_options=true
  case $opt in
    C)
      do_clean=true
      ;;
    c)
      do_compile=true
      ;;
    u)
      do_upload=true
      ;;
    f)
      do_flash_usb=true
      ;;
    l)
      do_logs=true
      ;;
    d)
      do_debug=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [config_file] [-C] [-c] [-u] [-f] [-l] [-d]"
      exit 1
      ;;
  esac
done

if [ "$do_debug" = true ]; then
  set -x
fi

# If no options provided, run compile + upload + logs by default
if [ "$has_options" = false ]; then
  do_compile=true
  do_upload=true
  do_logs=true
fi

truncate -s 0 "${logFile}"
do_it "$do_clean" "$do_compile" "$do_upload" "$do_flash_usb" "$do_logs" | tee -a "${logFile}"
