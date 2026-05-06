Build image command:

```docker buildx build --platform linux/amd64 -t vuhaipro2707/final-app:v1.0.0 ./app```

Push image command:

```docker push vuhaipro2707/final-app:v1.0.0```

```bash
/final-project
  ├── /app                 # Contains all source code, Dockerfile, docker-compose.dev.yml
  ├── /terraform           # Infrastructure (Server Configuration)
  ├── /ansible             # Provisioning (Install Docker, K8s on server)
  └── /k8s                 # Orchestration (Deployment, Service, Storage, HPA Configuration)
```

## Tool Installation Guide on macOS (For Local Machine)

Log in to AWS CLI using the command:

To run all deployment commands, you need to install the following tools via Homebrew:

```bash
# Install basic tools (MacOS)
brew install kubernetes-cli     # For 'kubectl' command
brew install helm               # For installing Drivers and Monitoring
brew install ansible            # For initializing Cluster
brew install terraform          # For building AWS infrastructure
brew install gettext            # For 'envsubst' command (processing variables in YAML)
brew install awscli             # For AWS CLI configuration
brew install httpd              # For 'ab' command (Apache Benchmark)
```

```bash
aws configure # Fill in Access Key, Secret Key, Region (e.g., us-east-1), output format (json)
```

## Deployment

0. Configure environment variables in the `.env` file (AWS_REGION, S3_BUCKET_NAME, etc.) from `.env.example`.

1. **Infrastructure Initialization (Terraform):**
   ```bash
   cd terraform
   terraform init
   export $(grep -v '^#' ../.env | xargs) && terraform apply -auto-approve -var="aws_region=$AWS_REGION" -var="s3_bucket_name=$S3_BUCKET_NAME"
   
   chmod +x generate_inventory.sh
   ./generate_inventory.sh
   cd ..
   ```   

2. **Cluster Initialization (Ansible):**
   ```bash
   cd ansible
   ansible-playbook -i inventory.ini install_k8s.yml
   ansible-playbook -i inventory.ini init_cluster.yml
   cd ..
   ```

   ```bash
   # Check if Cluster is ready
   kubectl --kubeconfig=ansible/admin.conf get nodes
   ```

3. **Drivers and Extensions Installation (Required for AWS):**
   ```bash
   # Install EBS CSI Driver for gp3 disks
   export KUBECONFIG=$PWD/ansible/admin.conf
   helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
   helm repo update
   helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
     --namespace kube-system
   ```

4. **Copy Worker 1 IP from inventory file to your domain DNS:**
   ```bash
   # Get Worker 1 IP
   WORKER_1_IP=$(grep 'worker-1' ansible/inventory.ini | awk '{print $2}' | cut -d'=' -f2)
   echo "Worker 1 IP: $WORKER_1_IP"
   ```

5. **Deploy App Infrastructure & Monitoring:**
   ```bash
   chmod +x k8s.sh
   ./k8s.sh
   ```

6. **Verify Status:**
   ```bash
   # Wait for all Certificates to be issued (Let's Encrypt)
   kubectl wait --for=condition=Ready certificate --all -A --timeout=300s
   ```

   ```bash
   # TROUBLESHOOTING: If Certificate is not READY, check the reason:
   kubectl get certificate -A
   kubectl describe certificate myapp-tls-secret
   ```
   
   ```bash
   # Check MongoDB ReplicaSet status
   kubectl exec -it mongodb-0 -- mongosh --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
   ```
   
   ```bash
   # Check Pod status
   kubectl get pods -o wide
   ```
   
   ```bash
   # Check All Pods status
   kubectl get pods -A -o wide
   ```
   
   ```bash
   # Check Node status
   kubectl get nodes
   ```

   ```bash
   # Check HPA status
   kubectl get hpa
   ```

7. **Stress Test & Auto-scaling (HPA):**
   ```bash
   # Perform stress test with Apache Benchmark (ab)
   # -n: total requests, -c: concurrent requests
   ab -n 10000 -c 100 https://{YOUR_DOMAIN}/
   ```

8. **Simulate Failures:**
   ```bash
   # Delete a MongoDB Pod to test self-healing
   kubectl delete pod mongodb-0
   ```

9. **Rollback:**
   Rollback command:
   ```bash
   chmod +x rollback_all_deployed.sh
   ./rollback_all_deployed.sh
   ```