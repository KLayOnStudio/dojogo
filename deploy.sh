#!/bin/bash

# Azure Functions Deployment Script for Dojogo
set -e

echo "🚀 Deploying Dojogo Azure Functions..."

# Check if logged in
if ! az account show &> /dev/null; then
    echo "❌ Not logged in to Azure. Please run: az login"
    exit 1
fi

# Variables - Update RESOURCE_GROUP to match your existing one
RESOURCE_GROUP="dojogo-rg"
LOCATION="centralus"
TIMESTAMP=$(date +%s)
STORAGE_NAME="dojogostorage${TIMESTAMP}"
FUNCTION_APP_NAME="dojogo-api"

echo "📋 Configuration:"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Storage Account: ${STORAGE_NAME}"
echo "  Function App: ${FUNCTION_APP_NAME}"
echo "  Location: ${LOCATION}"
echo ""

# Skip creating resource group since it already exists
echo "1. Using existing resource group: $RESOURCE_GROUP"

# Create storage account
echo "2. Creating storage account..."
az storage account create \
  --name $STORAGE_NAME \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_LRS

# Create function app
echo "3. Creating function app..."
az functionapp create \
  --resource-group $RESOURCE_GROUP \
  --consumption-plan-location $LOCATION \
  --runtime python \
  --runtime-version 3.11 \
  --functions-version 4 \
  --name $FUNCTION_APP_NAME \
  --storage-account $STORAGE_NAME \
  --os-type Linux

# Configure app settings
echo "4. Configuring database settings..."
az functionapp config appsettings set \
  --name $FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings \
  DB_HOST="dojogo-mysql-us-west2.mysql.database.azure.com" \
  DB_USER="klayon" \
  DB_PASSWORD="Zmfodyd4urAI" \
  DB_NAME="dojogo" \
  DB_PORT="3306"

# Get function app URL
echo "5. Getting function app URL..."
FUNCTION_URL=$(az functionapp show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP --query "defaultHostName" --output tsv)

echo ""
echo "✅ Azure resources created successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Deploy your code:"
echo "   cd dojogo-api"
echo "   func azure functionapp publish $FUNCTION_APP_NAME"
echo ""
echo "2. Update your iOS app APIService.swift:"
echo "   Replace: https://YOUR_AZURE_FUNCTION_APP_NAME.azurewebsites.net/api"
echo "   With:    https://$FUNCTION_URL/api"
echo ""
echo "🌐 Your Function App URL: https://$FUNCTION_URL"
echo ""