# Deployment Information

This directory contains documentation and configuration files for deploying Atlos. It is primarily oriented towards our own managed deployments, but you should be able to use these configuration files — perhaps with some modification — for your own deployments as well.

## Terraform

The terraform files specify a single Atlos deployment on Azure. Note that this deployment does *not* cover setting up the AWS components of azure (S3 or SES). Adding Terraform configurations for the AWS components is a nice-to-have for the future.

Steps to using the Terraform configs:

* Setup Terraform and [authenticate to Azure via the `az` CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) (note that we do not use Terraform in our CI; infrastructure changes must be deployed manually, because Miles is afraid to automate a potentially destructive action). If you're managing Atlos' own infrastructure (i.e., you're part of the Atlos team), make sure to set your subscription to our sponsored Azure subscription, and not a raw pay-as-you-go subscription.
* Create or edit a `.tfvars` file with values for the variables in `variables.tf`. The `variables.tf` file contains some documentation for each variable.
  * You will have to provide an `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for the S3 bucket and SES domain. These are not currently managed by Terraform, so you will have to create them manually. Ensure permissions are as narrow as possible.
* Run `terraform init` to initialize the Terraform state.
* Run `terraform plan -var-file=<your .tfvars file>` to see what changes will be made.
* Run `terraform apply -var-file=<your .tfvars file>` to apply the changes.
* Manually setup the custom domain for the Azure Container Apps environment. This is not yet automated, because it requires a manual DNS change.
* Verify that deletion protection and object versioning are enabled on the S3 bucket.
* Verify that the SES domain is verified and that the DKIM records are set up correctly.

To setup continuous deployment, you'll need to configure a GitHub environment with the following secrets:

* `AZURE_CREDENTIALS`: The output of `az ad sp create-for-rbac --name "github-actions" --role contributor --scopes /subscriptions/<subscription_id>/resourceGroups/<resource_group_id> --json-auth`
* `AZURE_CONTAINER_APP_NAME`: The name of the Azure Container App name
* `AZURE_CONTAINER_APP_RESOURCE_GROUP`: The name of the Azure Container Apps resource group

You'll also need to be sure that a corresponding GitHub Actions workflow file exists for the given deployment.

Each production deployment should have its own branch. Staging deploys out of the main branch, and the main platform is deployed out of the `deployments/platform` branch. Ensure proper branch protection rules are set up for production deployments.