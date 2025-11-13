#!/usr/bin/env bash
#
# Deploy script for Codex Gateway to Google Cloud Run
# Usage: ./deploy.sh [environment] [tag]
#   environment: prod | staging | dev (default: prod)
#   tag: Docker image tag (default: latest)
#
# Examples:
#   ./deploy.sh                    # Deploy prod with latest tag
#   ./deploy.sh staging            # Deploy staging with latest tag
#   ./deploy.sh prod v1.0.0        # Deploy prod with specific tag
#

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# ==============================================================================
# Configuration
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-prod}"
IMAGE_TAG="${2:-latest}"

# GCP Configuration
GCP_PROJECT="elaihub-prod"
GCP_REGION="us-central1"
ARTIFACT_REGISTRY="us-central1-docker.pkg.dev"
REPOSITORY="codex-wrapper"
IMAGE_NAME="wrapper"
SERVICE_NAME="wrapper"

# Full image path
FULL_IMAGE_PATH="${ARTIFACT_REGISTRY}/${GCP_PROJECT}/${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

log_info "🚀 Codex Gateway Deployment Script"
log_info "Environment: ${ENVIRONMENT}"
log_info "Image Tag: ${IMAGE_TAG}"
log_info "Full Image: ${FULL_IMAGE_PATH}"
echo ""

# Check if required tools are installed
for tool in gcloud docker; do
    if ! command -v $tool &> /dev/null; then
        log_error "$tool is not installed. Please install it first."
        exit 1
    fi
done

# Check if logged in to GCP
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    log_error "Not logged in to GCP. Run: gcloud auth login"
    exit 1
fi

# Set GCP project
log_info "Setting GCP project to ${GCP_PROJECT}..."
gcloud config set project "${GCP_PROJECT}"

# ==============================================================================
# Build Docker Image
# ==============================================================================

log_info "Building Docker image..."
cd "$(dirname "$0")/.."  # Go to project root

# Build the image
docker build \
    -f codex-rs/Dockerfile \
    -t "${FULL_IMAGE_PATH}" \
    codex-rs

log_success "Docker image built successfully"

# ==============================================================================
# Push to Artifact Registry
# ==============================================================================

log_info "Authenticating with Artifact Registry..."
gcloud auth configure-docker "${ARTIFACT_REGISTRY}" --quiet

log_info "Pushing image to Artifact Registry..."
docker push "${FULL_IMAGE_PATH}"

log_success "Image pushed to Artifact Registry"

# ==============================================================================
# Deploy to Cloud Run
# ==============================================================================

log_info "Deploying to Cloud Run..."

# Base deployment command
gcloud run services update "${SERVICE_NAME}" \
    --image="${FULL_IMAGE_PATH}" \
    --region="${GCP_REGION}" \
    --platform=managed \
    --service-account=467992722695-compute@developer.gserviceaccount.com \
    --max-instances=20 \
    --cpu=2 \
    --memory=4Gi \
    --timeout=300s \
    --concurrency=80 \
    --port=8080 \
    --set-env-vars="RUST_LOG=info,codex_gateway=debug" \
    --set-env-vars="PORT=8080" \
    --allow-unauthenticated

log_success "Deployed to Cloud Run"

# ==============================================================================
# Health Check
# ==============================================================================

log_info "Performing health check..."

# Get service URL
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --region="${GCP_REGION}" \
    --format='value(status.url)')

log_info "Service URL: ${SERVICE_URL}"

# Wait a bit for service to be ready
log_info "Waiting for service to be ready..."
sleep 10

# Health check
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${SERVICE_URL}/health")

if [ "$HTTP_STATUS" -eq 200 ]; then
    log_success "✅ Health check passed (HTTP ${HTTP_STATUS})"
    log_success "Deployment successful!"
    echo ""
    log_info "Service is now available at:"
    echo "  ${SERVICE_URL}"
    echo ""
    log_info "Test with:"
    echo "  curl ${SERVICE_URL}/health"
    echo "  curl -H 'X-API-Key: your-key' ${SERVICE_URL}/jsonrpc"
else
    log_error "❌ Health check failed (HTTP ${HTTP_STATUS})"
    log_error "Deployment may have issues. Check logs:"
    echo "  gcloud run services logs read ${SERVICE_NAME} --region=${GCP_REGION}"
    exit 1
fi

# ==============================================================================
# Optional: Show Recent Logs
# ==============================================================================

log_info "Recent logs (last 10 lines):"
gcloud run services logs read "${SERVICE_NAME}" \
    --region="${GCP_REGION}" \
    --limit=10 || true

log_success "🎉 Deployment complete!"
