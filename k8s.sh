#!/bin/bash

# Check config file
if [ ! -f "ansible/admin.conf" ]; then
    echo "Error: ansible/admin.conf not found. Please run Ansible first!"
    exit 1
fi

export KUBECONFIG=$PWD/ansible/admin.conf

echo "Step 1: Installing Ingress Controller (HostNetwork mode)..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml

# Patching to configure Ingress Controller
echo "Configuring Ingress Controller..."
kubectl patch deployment -n ingress-nginx ingress-nginx-controller --patch "$(cat k8s/ingress-patch.yaml)"

echo "Waiting for Ingress Controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  -l app.kubernetes.io/component=controller \
  --timeout=120s

echo "Step 1.2: Installing Cert-Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "Waiting for Cert-Manager to be ready..."
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=120s

echo "Step 1.5: Initializing Monitoring Namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "Step 1.7: Initializing Secrets from environment..."
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    export GRAFANA_PASSWORD_BASE64=$(echo -n "$GRAFANA_PASS" | base64)
    
    # Create secrets for both default and monitoring namespaces
    envsubst < k8s/secret.yaml | kubectl apply -f -
    envsubst < k8s/secret.yaml | kubectl apply -n monitoring -f -
else
    echo "Error: .env file missing, cannot create Secrets!"
    exit 1
fi

echo "Step 2: Configuring SSL Issuer..."
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    # Retry logic for Webhook availability
    for i in {1..5}; do
        envsubst < k8s/cert-manager-issuer.yaml | kubectl apply -f - && break || sleep 10
    done
else
    echo "Warning: .env file not found, skipping SSL Issuer setup"
fi

echo "Step 3: Installing StorageClass & Monitoring..."
kubectl apply -f k8s/storage-class.yaml
kubectl apply -f k8s/monitoring/prometheus-rbac.yaml

# Fix Prometheus: Use envsubst to pass environment variables (APP_DOMAIN)
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    envsubst < k8s/monitoring/prometheus.yaml | kubectl apply -f -
else
    kubectl apply -f k8s/monitoring/prometheus.yaml
fi

# Apply remaining monitoring configurations
for f in k8s/monitoring/*.yaml; do
    if [[ "$f" != *"prometheus.yaml"* ]]; then
        kubectl apply -f "$f"
    fi
done

echo "Step 4: Deploying MongoDB HA (3 Nodes)..."
kubectl apply -f k8s/mongodb.yaml

echo "Step 5: Deploying Application & HPA..."
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/hpa.yaml

echo "Step 6: Configuring Ingress (Path-based Routing)..."
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    # Retry logic for Webhook readiness
    for i in {1..5}; do
        envsubst < k8s/ingress.yaml | kubectl apply -f - && \
        envsubst < k8s/monitoring-ingress.yaml | kubectl apply -f - && break || \
        (echo "Warning: Webhook not ready, retrying in 10s..." && sleep 10)
    done
else
    for i in {1..5}; do
        kubectl apply -f k8s/ingress.yaml && \
        kubectl apply -f k8s/monitoring-ingress.yaml && break || \
        (echo "Warning: Webhook not ready, retrying in 10s..." && sleep 10)
    done
fi

echo "COMPLETED! The system is being deployed."
echo "------------------------------------------------"
WORKER1_IP=$(kubectl get node worker-1 -o jsonpath='{.status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$WORKER1_IP" ]; then
    WORKER1_IP=$(grep "worker-1" ansible/inventory.ini | sed -E 's/.*ansible_host=([^ ]*).*/\1/')
fi
echo "Worker 1 IP Address: $WORKER1_IP"
echo "------------------------------------------------"
echo "Check status with: kubectl get pods -A"
