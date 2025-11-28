#!/bin/bash
# Deploy Conbench to EKS cluster created by Terraform

set -e

cd "$(dirname "$0")/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deploying Conbench to EKS${NC}"

# Get values from Terraform
export DB_HOST=$(cd terraform && terraform output -raw rds_instance_address)
export DB_PORT=$(cd terraform && terraform output -raw rds_instance_port)
export DB_USERNAME=$(cd terraform && terraform output -raw rds_master_username)
export DB_NAME="${DB_NAME:-conbench_prod}"  # Default to conbench_prod

echo -e "${YELLOW}Database configuration:${NC}"
echo "  DB_HOST: $DB_HOST"
echo "  DB_PORT: $DB_PORT"
echo "  DB_USERNAME: $DB_USERNAME"
echo "  DB_NAME: $DB_NAME"
echo ""

# Check if required environment variables are set
if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}Error: DB_PASSWORD environment variable not set${NC}"
    echo "Please set it: export DB_PASSWORD='your-password'"
    exit 1
fi

if [ -z "$GITHUB_API_TOKEN" ]; then
    echo -e "${YELLOW}Warning: GITHUB_API_TOKEN not set${NC}"
fi

if [ -z "$SECRET_KEY" ]; then
    echo -e "${YELLOW}Warning: SECRET_KEY not set, generating random one${NC}"
    export SECRET_KEY=$(openssl rand -base64 32)
fi

if [ -z "$REGISTRATION_KEY" ]; then
    echo -e "${YELLOW}Warning: REGISTRATION_KEY not set, generating random one${NC}"
    export REGISTRATION_KEY=$(openssl rand -base64 16)
fi

# Optional: Set defaults for other variables
export CONBENCH_INTENDED_BASE_URL="${CONBENCH_INTENDED_BASE_URL:-https://conbench.arrow-dev.org}"
export APPLICATION_NAME="${APPLICATION_NAME:-Conbench}"
export BENCHMARKS_DATA_PUBLIC="${BENCHMARKS_DATA_PUBLIC:-true}"
export FLASK_APP="${FLASK_APP:-conbench}"
export DISTRIBUTION_COMMITS="${DISTRIBUTION_COMMITS:-100}"
export SVS_TYPE="${SVS_TYPE:-}"
export GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
export GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"

echo -e "${GREEN}Step 1: Creating Kubernetes ConfigMap${NC}"

# Apply ConfigMap
cat conbench-config.yml | sed "\
    s|{{CONBENCH_INTENDED_BASE_URL}}|${CONBENCH_INTENDED_BASE_URL}|g; \
    s/{{APPLICATION_NAME}}/${APPLICATION_NAME}/g; \
    s/{{BENCHMARKS_DATA_PUBLIC}}/${BENCHMARKS_DATA_PUBLIC}/g; \
    s/{{DB_NAME}}/${DB_NAME}/g; \
    s/{{DB_HOST}}/${DB_HOST}/g; \
    s/{{DB_PORT}}/${DB_PORT}/g; \
    s/{{FLASK_APP}}/${FLASK_APP}/g; \
    s/{{DISTRIBUTION_COMMITS}}/${DISTRIBUTION_COMMITS}/g; \
    s/{{SVS_TYPE}}/${SVS_TYPE}/g" | kubectl apply -f -

echo -e "${GREEN}Step 2: Creating Kubernetes Secret${NC}"

# Apply Secret
if [ -z "$GOOGLE_CLIENT_ID" ]; then
    cat conbench-secret.yml | sed "\
        s/{{DB_PASSWORD}}/$(echo -n $DB_PASSWORD | base64)/g; \
        s/{{DB_USERNAME}}/$(echo -n $DB_USERNAME | base64)/g; \
        s/{{GITHUB_API_TOKEN}}/$(echo -n $GITHUB_API_TOKEN | base64)/g; \
        s/GOOGLE_CLIENT_ID: {{GOOGLE_CLIENT_ID}}//g; \
        s/GOOGLE_CLIENT_SECRET: {{GOOGLE_CLIENT_SECRET}}//g; \
        s/{{REGISTRATION_KEY}}/$(echo -n $REGISTRATION_KEY | base64)/g; \
        s/{{SECRET_KEY}}/$(echo -n $SECRET_KEY | base64)/g" | kubectl apply -f -
else
    cat conbench-secret.yml | sed "\
        s/{{DB_PASSWORD}}/$(echo -n $DB_PASSWORD | base64)/g; \
        s/{{DB_USERNAME}}/$(echo -n $DB_USERNAME | base64)/g; \
        s/{{GITHUB_API_TOKEN}}/$(echo -n $GITHUB_API_TOKEN | base64)/g; \
        s/{{GOOGLE_CLIENT_ID}}/$(echo -n $GOOGLE_CLIENT_ID | base64 -w 0)/g; \
        s/{{GOOGLE_CLIENT_SECRET}}/$(echo -n $GOOGLE_CLIENT_SECRET | base64)/g; \
        s/{{REGISTRATION_KEY}}/$(echo -n $REGISTRATION_KEY | base64)/g; \
        s/{{SECRET_KEY}}/$(echo -n $SECRET_KEY | base64)/g" | kubectl apply -f -
fi

echo -e "${GREEN}Step 3: Deploying Conbench Service${NC}"
kubectl apply -f k8s/conbench-service.yml

echo -e "${GREEN}Step 4: Building and pushing Docker image${NC}"
echo -e "${YELLOW}Note: You need to have an ECR repository set up and DOCKER_REGISTRY configured${NC}"

# Check if we should deploy
read -p "Do you have a Conbench Docker image ready in ECR? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter the full image spec (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/conbench:latest): " IMAGE_SPEC

    echo -e "${GREEN}Step 5: Deploying Conbench Application${NC}"
    cat k8s/conbench-deployment.templ.yml | \
        sed "s|{{CONBENCH_WEBAPP_IMAGE_SPEC}}|${IMAGE_SPEC}|g" | kubectl apply -f -

    echo -e "${GREEN}Deployment initiated!${NC}"
    echo ""
    echo "Monitor deployment status:"
    echo "  kubectl get pods"
    echo "  kubectl logs -f deployment/conbench-deployment"
    echo ""
    echo "To access Conbench:"
    echo "  kubectl port-forward svc/conbench-service 5000:80"
    echo "  Then visit: http://localhost:5000"
else
    echo -e "${YELLOW}Skipping deployment. Build and push your image first.${NC}"
    echo "See: https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html"
fi

echo ""
echo -e "${GREEN}Configuration saved:${NC}"
echo "  REGISTRATION_KEY: $REGISTRATION_KEY"
echo "  SECRET_KEY: [hidden]"
echo ""
echo -e "${YELLOW}Save these values! You'll need the REGISTRATION_KEY to create user accounts.${NC}"
