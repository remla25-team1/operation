#!/usr/bin/env bash
set -euo pipefail

SLEEP_TIME=2
STATE_FILE=".run.sh.state"

# ──────────────────────────────────────────────────────────────────────────────
step1_vagrant_up() {
  echo "-> [Step 1] vagrant up"
  vagrant up
  echo 2 > "$STATE_FILE"
  echo "Sleeping ${SLEEP_TIME}s…"; sleep "$SLEEP_TIME"
}

step2_finalize() {
  echo "-> [Step 2] ansible-playbook finalization.yaml"
  ansible-playbook \
    -u vagrant \
    -i 192.168.56.100, \
    playbooks/finalization.yaml \
    --extra-vars "cluster_network=192.168.56 ctrl_ip=192.168.56.100"
  echo 3 > "$STATE_FILE"
  echo "Sleeping ${SLEEP_TIME}s…"; sleep "$SLEEP_TIME"
}

step3_migrate() {
  echo "-> [Step 3] prompt for GitHub credentials"
  read -p "GitHub username: " GITHUB_USERNAME
  read -s -p "GitHub Personal Access Token: " GITHUB_PAT
  echo
  read -p "GitHub email: " GITHUB_EMAIL

  echo "-> [Step 4] ansible-playbook migrate.yaml"
  ansible-playbook \
    -i shared/inventory.ini playbooks/migrate.yaml \
    --ask-become-pass \
    -e github_username="${GITHUB_USERNAME}" \
    -e github_pat="${GITHUB_PAT}" \
    -e github_email="${GITHUB_EMAIL}"
  echo 5 > "$STATE_FILE"
  echo "Sleeping ${SLEEP_TIME}s…"; sleep "$SLEEP_TIME"
}

step4_export_kubeconfig() {
  echo "-> [Step 5] Final instructions for using kubectl"
  echo
  echo "⚠️ Note: To use kubectl with your cluster, run the following command in your terminal:"
  echo
  echo " export KUBECONFIG=\"\$(pwd)/kubeconfig-vagrant\""
  echo
  echo "This step cannot be applied permanently from inside the script."
  echo
  echo "You can find the app frontend at:"
  echo " http://http://192.168.56.91"
  echo
  echo "✅ Script completed successfully."
  rm -f "$STATE_FILE"
}


# ──────────────────────────────────────────────────────────────────────────────
if [[ -f "$STATE_FILE" ]]; then
  START_AT=$(<"$STATE_FILE")
  echo -e "State file found; resuming from step $START_AT (recorded in $STATE_FILE).\nIf you wish to run the script from start, remove the shell state file and try again."
else
  START_AT=1
  echo "No state file found; starting at step 1"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Only move the state forward **after** a step finishes successfully.
if (( START_AT <= 1 )); then
  step1_vagrant_up
fi

if (( START_AT <= 2 )); then
  step2_finalize
fi

if (( START_AT <= 3 )); then
  step3_migrate
fi

if (( START_AT <= 5 )); then
  step4_export_kubeconfig
fi
