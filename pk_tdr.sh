#!/bin/bash

### functions
function do_exit {
  local exit_code=$1
  local msg=$2
  if [ "$do_debug" = true ]; then
    set -x
  fi
  if [ "$exit_code" -ne 0 ]; then
    echo "ERREUR: $msg"
  fi
  exit "$exit_code"
}

## Script de gestion ESPHome Nexxtender
## Usage: sh pk_tdr.sh [-C] [-c] [-u] [-l]
# -C : clean (nettoyer le build)
# -c : compile
# -u : upload (via OTA nexxtender.local)
# -l : logs (afficher les logs en temps réel)
# Sans option : compile + upload + logs

yamlFile="nexxtender.local.yaml"
device="nexxtender.local"
logFile="nexxtender.log"

# Flags par défaut
do_clean=false
do_compile=false
do_upload=false
do_logs=false
has_options=false
do_debug=false

# Parser les options
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
      truncate -s 0 "${logFile}"
      ;;
    d)
      do_debug=true
      ;;
    \?)
      echo "Option invalide: -$OPTARG" >&2
      echo "Usage: $0 [-C] [-c] [-u] [-l]"
      exit 1
      ;;
  esac
done

if [ "$do_debug" = true ]; then
  set -x
fi

# Si aucune option, faire compile + upload + logs par défaut
if [ "$has_options" = false ]; then
  do_compile=true
  do_upload=true
  do_logs=true
fi

# Exécution des commandes selon les flags
echo "=== ESPHome Nexxtender Manager ==="
echo "Fichier de configuration: ${yamlFile}"
echo "Appareil cible: ${device}"
echo ""

if [ "$do_clean" = true ]; then
  echo ">>> Nettoyage du build..."
  if ! esphome clean "${yamlFile}"; then
    do_exit 1 "La commande de nettoyage a échoué"
  fi
  echo "✓ Nettoyage terminé"
  echo ""
fi

if [ "$do_compile" = true ]; then
  echo ">>> Compilation du firmware..."
  if ! esphome compile "${yamlFile}"; then
    do_exit 1 "La commande de compilation a échoué"
  fi
  echo "✓ Compilation terminée"
  echo ""
fi

if [ "$do_upload" = true ]; then
  echo ">>> Upload du firmware via OTA..."
  if ! esphome upload "${yamlFile}" --device "${device}"; then
    do_exit 1 "La commande d'upload a échoué"
  fi
  echo "✓ Upload terminé"
  echo ""
fi

if [ "$do_logs" = true ]; then
  echo ">>> Affichage des logs (Ctrl+C pour quitter)..."
  esphome logs "${yamlFile}" --device "${device}" | tee -a "${logFile}"
fi

echo ""
echo "=== Terminé ==="
