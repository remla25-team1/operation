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
  echo "Using GitHub credentials for migration: $GITHUB_USERNAME, $GITHUB_EMAIL"
  echo

  # Fetch the two most recent tags matching vX.X.X
  TAGS=($(curl -s https://api.github.com/repos/remla25-team1/app/releases \
    | grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' \
    | cut -d '"' -f4 \
    | sort -Vr \
    | head -n 2))

  if [ "${#TAGS[@]}" -eq 0 ]; then
    echo "Error: No vX.X.X tags found in the repository."
    exit 1
  elif [ "${#TAGS[@]}" -eq 1 ]; then
    LATEST_TAG="${TAGS[0]}"
    PREV_TAG="${TAGS[0]}"
  else
    LATEST_TAG="${TAGS[0]}"
    PREV_TAG="${TAGS[1]}"
  fi

  echo "Using v1 tag: $LATEST_TAG for app-v1"
  echo "Using v2 tag: $PREV_TAG for app-v2"

  TAG=($(curl -s https://api.github.com/repos/remla25-team1/model-service/releases \
    | grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' \
    | head -n 1 \
    | cut -d '"' -f4))
  
  if [ -z "$TAG" ]; then
    echo "Error: No vX.X.X tag found for model-service."
    exit 1
  fi

  # Update tags using yq
  yq e ".app.v1.image.tag = \"$LATEST_TAG\"" -i helm_chart/values.yaml
  yq e ".app.v2.image.tag = \"$PREV_TAG\"" -i helm_chart/values.yaml
  yq e ".modelService.image.tag = \"$TAG\"" -i helm_chart/values.yaml

  echo "Set app v1 tag to $LATEST_TAG, app v2 tag to $PREV_TAG, model-service tag to $TAG in values.yaml"


  # Update .env file for docker-compose
  # ──────────────────────────────────────────────────────────────────────────────
  echo "Updating .env with latest tags ($LATEST_TAG, $TAG)..."

  # backup old .env
  cp .env .env.bak

  # set both variables to the new latest tag
  sed -i -E "s#^APP_SERVICE_VERSION=.*#APP_SERVICE_VERSION=${LATEST_TAG}#" .env
  sed -i -E "s#^MODEL_SERVICE_VERSION=.*#MODEL_SERVICE_VERSION=${TAG}#" .env

  echo ".env updated:"
  grep -E '^(APP_SERVICE_VERSION|MODEL_SERVICE_VERSION)' .env


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
  echo "You can find the app frontend at:"
  echo " http://192.168.56.91"
  echo
  echo "✅ Script completed successfully."
  rm -f "$STATE_FILE"
}

# ──────────────────────────────────────────────────────────────────────────────
if [[ -f "$STATE_FILE" ]]; then
  START_AT=$(<"$STATE_FILE")
  echo -e "State file found; resuming from step $START_AT (recorded in $STATE_FILE).\nIf you wish to run the script from start, remove the shell state file and try again."
  echo
else
  START_AT=1
  echo "No state file found; starting at step 1"
  echo
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