# Terraform Infrastructure for Codex Gateway

This directory contains Terraform configuration for provisioning the GCP infrastructure needed by the Codex Gateway.

## Resources Created

1. **Cloud Storage Bucket** - For storing generated artifacts
   - Versioning enabled
   - Lifecycle policies (30 days retention)
   - IAM permissions for service account

2. **Firestore Database** - For API keys and session management
   - Native mode
   - Optimistic concurrency
   - Deployed in the specified region

3. **Secret Manager Secrets** - For sensitive credentials
   - Gateway API key
   - Anthropic API key
   - OpenAI API key (optional)
   - Pipedrive API token (optional)

4. **IAM Permissions** - Proper access controls
   - Service account access to secrets
   - Service account access to storage bucket

5. **Cloud Monitoring** - Log-based metrics
   - API request metrics
   - Error tracking

## Prerequisites

1. **Install Terraform** (>= 1.5.0)
   ```bash
   brew install terraform  # macOS
   # or download from https://www.terraform.io/downloads
   ```

2. **Authenticate with GCP**
   ```bash
   gcloud auth application-default login
   gcloud config set project elaihub-prod
   ```

3. **Enable required APIs**
   ```bash
   gcloud services enable \
     cloudresourcemanager.googleapis.com \
     serviceusage.googleapis.com \
     storage.googleapis.com \
     firestore.googleapis.com \
     secretmanager.googleapis.com \
     logging.googleapis.com \
     monitoring.googleapis.com
   ```

## Usage

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Review the plan

```bash
terraform plan
```

### 3. Apply the configuration

```bash
terraform apply
```

Review the changes and type `yes` to confirm.

### 4. Configure secrets

After applying, you need to add the actual secret values:

```bash
# Gateway API Key
echo -n "your-gateway-api-key" | \
  gcloud secrets versions add gateway-api-key --data-file=-

# Anthropic API Key
echo -n "sk-ant-your-key" | \
  gcloud secrets versions add anthropic-api-key --data-file=-

# OpenAI API Key (optional)
echo -n "sk-your-openai-key" | \
  gcloud secrets versions add openai-api-key --data-file=-

# Pipedrive API Token (optional)
echo -n "your-pipedrive-token" | \
  gcloud secrets versions add pipedrive-api-token --data-file=-
```

## Customization

Copy `terraform.tfvars.example` to `terraform.tfvars` and adjust values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific values.

## State Management

By default, Terraform state is stored locally. For production, consider using a remote backend:

1. Create a GCS bucket for state:
   ```bash
   gsutil mb gs://elaihub-prod-terraform-state
   gsutil versioning set on gs://elaihub-prod-terraform-state
   ```

2. Uncomment the backend configuration in `main.tf`

3. Initialize with the backend:
   ```bash
   terraform init -migrate-state
   ```

## Outputs

After applying, Terraform will output important information:

- `artifacts_bucket_name` - Name of the GCS bucket
- `artifacts_bucket_url` - URL of the GCS bucket
- `firestore_database_name` - Firestore database name
- `secret_ids` - IDs of created secrets

View outputs anytime with:
```bash
terraform output
```

## Cleanup

To destroy all resources (use with caution):

```bash
terraform destroy
```

## Troubleshooting

### Permission Denied Errors

Ensure your GCP account has the following roles:
- Storage Admin
- Firestore Admin
- Secret Manager Admin
- Logging Admin
- Monitoring Admin

### Firestore Already Exists

If Firestore is already configured in your project, comment out the `google_firestore_database` resource in `main.tf`.

### API Not Enabled

Enable required APIs:
```bash
gcloud services enable firestore.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

## Best Practices

1. **Use separate environments** - Create different Terraform workspaces or directories for prod/staging
2. **Version control** - Commit terraform files (but not `.tfstate` or `.tfvars` with secrets)
3. **Review changes** - Always run `terraform plan` before `apply`
4. **State backup** - Keep backups of your Terraform state
5. **Secret rotation** - Regularly rotate secrets in Secret Manager

## Additional Resources

- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GCP Secret Manager](https://cloud.google.com/secret-manager/docs)
- [GCP Firestore](https://cloud.google.com/firestore/docs)
- [GCP Cloud Storage](https://cloud.google.com/storage/docs)
