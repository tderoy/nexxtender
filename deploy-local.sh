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

## ESPHome Nexxtender Local Deployment Script
## Usage: sh deploy-local.sh [-C] [-c] [-u] [-l] [-d]
# -C : clean (clean build directory)
# -c : compile only
# -u : upload (via OTA to nexxtender.local)
# -l : logs (display real-time logs)
# -d : debug mode
# Without options: compile + upload + logs

yamlFile="nexxtender.local.yaml"
device="nexxtender.local"
logFile="nexxtender.log"

# Default flags
do_clean=false
do_compile=false
do_upload=false
do_logs=false
has_options=false
do_debug=false

# Parse options
while getopts "Cculd" opt; do
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
    l)
      do_logs=true
      ;;
    d)
      do_debug=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [-C] [-c] [-u] [-l] [-d]"
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

if [ "$do_logs" = true ]; then
  echo ">>> Displaying logs (Ctrl+C to quit)..."
  export PYTHONIOENCODING=utf-8
  truncate -s 0 "${logFile}"
  esphome logs "${yamlFile}" --device "${device}" | tee -a "${logFile}"
fi

echo ""
echo "=== Completed ==="
