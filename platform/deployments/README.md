# Deployment Information

This directory contains documentation and configuration files for deploying Atlos. It is primarily oriented towards our own managed deployments, but you should be able to use these configuration files — perhaps with some modification — for your own deployments as well.

## Terraform

The terraform files specify a single Atlos deployment on Azure. Note that this deployment does *not* cover setting up the AWS components of azure (S3 or SES). Adding Terraform configurations for the AWS components is a nice-to-have for the future.

Steps to using the Terraform configs:

* Setup Terraform and [authenticate to Azure via the `az` CLI](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) (note that we do not use Terraform in our CI; infrastructure changes must be deployed manually, because Miles is afraid to automate a potentially destructive action). If you're managing Atlos' own infrastructure (i.e., you're part of the Atlos team), make sure to set your subscription to our sponsored Azure subscription, and not a raw pay-as-you-go subscription.
* Create or edit a `.tfvars` file with values for the variables in `variables.tf`. The `variables.tf` file contains some documentation for each variable.
* Run `terraform init` to initialize the Terraform state.
* Run `terraform plan -var-file=<your .tfvars file>` to see what changes will be made.
* Run `terraform apply -var-file=<your .tfvars file>` to apply the changes.
* Manually setup the custom domain for the Azure Container Apps environment. This is not yet automated, because it requires a manual DNS change.
* Verify that deletion protection and object versioning are enabled on the S3 bucket.
* Verify that the SES domain is verified and that the DKIM records are set up correctly.
