# Arrow BCI Kubernetes Setup with Terraform

This document explains how to deploy the Arrow BCI application to your EKS cluster using Terraform.

## What's Included

The new `arrow_bci_k8s.tf` file creates:

1. **ConfigMap** (`arrow-bci-config`) - Application configuration
2. **Secret** (`arrow-bci-secrets`) - Sensitive credentials
3. **Deployment** (`arrow-bci-deployment`) - Application pods
4. **Service** (`arrow-bci-service`) - LoadBalancer with SSL
5. **Route53 Record** - DNS for `arrow-bci.arrow-dev.org`

## Prerequisites

Before deploying:

1. **EKS cluster** must be created (`terraform apply` for infrastructure)
2. **RDS arrow_bci database** must exist
3. **AWS Load Balancer Controller** is NOT required (using Classic ELB)
4. **ACM Certificate** for `*.arrow-dev.org` (already exists)

## Configuration

### Required Variables

Add these to your `terraform.tfvars`:

```hcl
# Arrow BCI Application
arrow_bci_image    = "855673865593.dkr.ecr.us-east-1.amazonaws.com/conbench:latest"
arrow_bci_replicas = 1

# Secrets (sensitive - do not commit!)
db_password         = "your-database-password"
github_api_token    = "ghp_xxxxxxxxxxxx"
slack_api_token     = "xoxb-xxxxxxxxxxxx"  # Optional
buildkite_api_token = "your-buildkite-token"
```

### Optional Variables

Already have defaults:

```hcl
buildkite_api_base_url = "https://api.buildkite.com/v2"
buildkite_org          = "apache-arrow"
conbench_url           = "https://conbench.arrow-dev.org"
flask_app              = "conbench"
github_api_base_url    = "https://api.github.com"
github_repo            = "apache/arrow"
max_commits_to_fetch   = "10"
pypi_api_base_url      = "https://pypi.org/pypi"
pypi_project           = "pyarrow"
slack_api_base_url     = "https://slack.com/api"
```

## Deployment Steps

### 1. Review the Configuration

```bash
cd terraform
terraform plan
```

### 2. Apply the Changes

```bash
terraform apply
```

This will:
- Create the ConfigMap with database connection details
- Create the Secret with credentials
- Deploy the Arrow BCI application (1 replica by default)
- Create a LoadBalancer service with SSL
- Create DNS record for `arrow-bci.arrow-dev.org`

### 3. Verify Deployment

```bash
# Check outputs
terraform output arrow_bci_url
terraform output arrow_bci_health_check_url

# Verify the health check
curl https://arrow-bci.arrow-dev.org/health-check
```

## Accessing the Application

- **Main URL**: https://arrow-bci.arrow-dev.org
- **Health Check**: https://arrow-bci.arrow-dev.org/health-check

## Monitoring

### Check Pod Status

```bash
kubectl get pods -l app=arrow-bci
kubectl logs -f deployment/arrow-bci-deployment
```

### Check Service Status

```bash
kubectl get svc arrow-bci-service
kubectl describe svc arrow-bci-service
```

### Check DNS Resolution

```bash
nslookup arrow-bci.arrow-dev.org
```

## Scaling

To scale the number of replicas:

```hcl
# In terraform.tfvars
arrow_bci_replicas = 2
```

Then apply:

```bash
terraform apply
```

## Updating the Application

### Update Docker Image

```hcl
# In terraform.tfvars
arrow_bci_image = "855673865593.dkr.ecr.us-east-1.amazonaws.com/conbench:v1.2.3"
```

Apply changes:

```bash
terraform apply
```

### Update Configuration

Edit variables in `terraform.tfvars` and run:

```bash
terraform apply
```

Terraform will update the ConfigMap/Secret and automatically roll out the deployment.

## Troubleshooting

### Pod Not Starting

Check logs:
```bash
kubectl logs -f deployment/arrow-bci-deployment
kubectl describe pod -l app=arrow-bci
```

### LoadBalancer Not Created

Check service status:
```bash
kubectl describe svc arrow-bci-service
```

Ensure your EKS nodes have proper IAM permissions for ELB creation.

### DNS Not Resolving

The Route53 record depends on the LoadBalancer being created first. Check:

```bash
terraform output arrow_bci_service_hostname
```

If it shows "pending", wait for the LoadBalancer to be provisioned (takes 2-3 minutes).

### SSL Certificate Issues

Verify the certificate ARN:
```bash
terraform output arrow_dev_certificate_arn
```

The certificate must cover `*.arrow-dev.org` or specifically `arrow-bci.arrow-dev.org`.

## Cost Impact

Adding Arrow BCI deployment:
- **Additional EKS pods**: No cost (uses existing node capacity)
- **LoadBalancer (Classic ELB)**: ~$16/month + data transfer
- **Total additional cost**: ~$16/month

## Cleanup

To remove Arrow BCI resources:

```bash
# Remove just the Kubernetes resources
terraform destroy -target=kubernetes_deployment.arrow_bci \
                  -target=kubernetes_service.arrow_bci \
                  -target=kubernetes_config_map.arrow_bci \
                  -target=kubernetes_secret.arrow_bci \
                  -target=aws_route53_record.arrow_bci
```

## Security Notes

1. **Secrets**: Never commit `terraform.tfvars` with real secrets
2. **Database Password**: Use AWS Secrets Manager in production
3. **API Tokens**: Rotate regularly and use scoped permissions
4. **SSL/TLS**: All traffic is encrypted via the LoadBalancer

## Next Steps

After successful deployment:

1. Configure Buildkite pipelines for benchmarking
2. Set up monitoring and alerting
3. Configure backup strategy
4. Review and adjust resource limits
