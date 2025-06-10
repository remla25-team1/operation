#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Check if the script is being sourced (to safely unset env variables)
sourced=0
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && sourced=1

# ──────────────────────────────────────────────────────────────────────────────
# Vagrant Teardown
echo "-> Destroying the Vagrant cluster..."
vagrant destroy -f

# ──────────────────────────────────────────────────────────────────────────────
# Docker Network Check
echo "→ Checking for leftover Docker networks..."
docker network ls

echo
read -p "Would you like to remove any lingering Docker network manually? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
  echo "Use: docker network rm <network_id>"
else
  echo "Skipping manual Docker network removal."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Unset KUBECONFIG
if [[ -n "${KUBECONFIG:-}" ]]; then
  echo "-> Unsetting KUBECONFIG: $KUBECONFIG"
  if [[ $sourced -eq 1 ]]; then
    unset KUBECONFIG
  else
    echo "Note: KUBECONFIG was set in the parent shell — run 'unset KUBECONFIG' manually or source this script to fully clean up the environment."
  fi
else
  echo "-> No KUBECONFIG variable set. Nothing to unset."
fi

# ──────────────────────────────────────────────────────────────────────────────
echo "✓ Cleanup complete."

# Exit or return depending on context
if [[ $sourced -eq 1 ]]; then
  return 0
else
  exit 0
fi
