#!/bin/bash
set -e

INVENTORY="../ansible/inventory.ini"
KEY_PATH="~/.ssh/id_rsa"

echo "Waiting for all Terraform outputs to be ready..."
MAX_RETRIES=12
RETRY_COUNT=0
REQUIRED_OUTPUTS=("master_ip" "worker_ips" "s3_bucket_name")

while true; do
  ALL_READY=true
  MISSING_OUTPUTS=()
  for out in "${REQUIRED_OUTPUTS[@]}"; do
    # Check if output exists and is not empty
    OUT_VALUE=$(terraform output -json "$out" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$OUT_VALUE" == "null" ] || [ "$OUT_VALUE" == "[]" ] || [ -z "$OUT_VALUE" ]; then
      ALL_READY=false
      MISSING_OUTPUTS+=("$out")
    fi
  done

  if [ "$ALL_READY" = true ]; then
    echo "All outputs are ready!"
    break
  fi

  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "Error: Timeout waiting for terraform outputs. Missing: ${MISSING_OUTPUTS[*]}"
    exit 1
  fi

  echo "Waiting for outputs: [${MISSING_OUTPUTS[*]}] (Attempt $RETRY_COUNT/$MAX_RETRIES, retrying in 10s...)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo "[master]" > "$INVENTORY"
MASTER_IP=$(terraform output -raw master_ip)
echo "master-node ansible_host=$MASTER_IP ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH" >> "$INVENTORY"

echo -e "\n[workers]" >> "$INVENTORY"
WORKER_IPS=$(terraform output -json worker_ips | jq -r '.[]')

i=1
for ip in $WORKER_IPS; do
  echo "worker-$i ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=$KEY_PATH" >> "$INVENTORY"
  i=$((i+1))
done

echo -e "\n[k8s_cluster:children]\nmaster\nworkers" >> "$INVENTORY"

echo "Inventory generated at $INVENTORY"

VARS="../ansible/vars.yml"
BUCKET_NAME=$(terraform output -raw s3_bucket_name)

REGION=$(grep AWS_REGION ../.env | cut -d '=' -f2)

echo "---" > "$VARS"
echo "s3_bucket_name: $BUCKET_NAME" >> "$VARS"
echo "aws_region: $REGION" >> "$VARS"

echo "Inventory and Vars generated!"
