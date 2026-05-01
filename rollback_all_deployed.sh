#!/bin/bash

# Load environment variables from .env
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found!"
    exit 1
fi

export KUBECONFIG=$PWD/ansible/admin.conf

echo "--- Step 1: Collecting EBS Volume IDs for MongoDB ---"
# Get IDs of EBS volumes used by MongoDB
EBS_IDS=$(kubectl get pv -o jsonpath='{.items[*].spec.csi.volumeHandle}' 2>/dev/null)

if [ -z "$EBS_IDS" ]; then
    echo "No EBS volumes found or Kubeconfig not accessible. Skipping EBS cleanup list."
else
    echo "Found volumes: $EBS_IDS"
    echo "$EBS_IDS" > terraform/ebs_volumes_to_delete.txt
fi

echo ""
echo "--- Step 2: Destroying Infrastructure with Terraform ---"
cd terraform
terraform destroy -auto-approve -var="aws_region=$AWS_REGION" -var="s3_bucket_name=$S3_BUCKET_NAME"

echo ""
echo "--- Step 3: Cleaning up EBS Volumes (Post-Destroy) ---"
if [ -f ebs_volumes_to_delete.txt ]; then
    for id in $(cat ebs_volumes_to_delete.txt); do
        echo "Deleting volume: $id"
        aws ec2 delete-volume --volume-id $id 2>/dev/null || echo "Volume $id already deleted or not found."
    done
    rm ebs_volumes_to_delete.txt
fi
cd ..

echo ""
echo "--- Step 4: Cleaning up local configuration files ---"
rm -f ansible/inventory.ini
rm -f ansible/vars.yml
rm -f ansible/admin.conf

echo ""
echo "Rollback completed successfully!"
