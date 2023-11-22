terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.81.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "=3.5.1"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}

  skip_provider_registration = true
}

# Configure the random provider
provider "random" {

}