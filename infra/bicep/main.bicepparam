using './main.bicep'

param webAppName string = uniqueString(resourceGroup().id) // Generate a unique string for the web app name
param sku string = 'F1' // Tier of the App Service plan
param linuxFxVersion string = 'node|20-lts' // Runtime stack of the web app
param location string = resourceGroup().location // Location for all resources
param repositoryUrl string = 'https://github.com/Azure-Samples/nodejs-docs-hello-world'
param branch string = 'main'