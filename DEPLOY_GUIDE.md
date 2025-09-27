# Azure Functions Deployment Guide

## Prerequisites
✅ Azure CLI installed (already done)
✅ Azure Functions project created (already done)
✅ MySQL database setup (already done)

## Step-by-Step Deployment

### 1. Login to Azure
Open Terminal and run:
```bash
az login
```
This will open a browser window - log in with your Azure account credentials.

### 2. Set Your Subscription (if you have multiple)
```bash
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_NAME"
```

### 3. Create Resource Group (if needed)
```bash
az group create --name dojogo-rg --location "West US 2"
```

### 4. Create Storage Account
```bash
az storage account create \
  --name dojogostorage$(date +%s) \
  --location "West US 2" \
  --resource-group dojogo-rg \
  --sku Standard_LRS
```

### 5. Create Function App
```bash
az functionapp create \
  --resource-group dojogo-rg \
  --consumption-plan-location "West US 2" \
  --runtime python \
  --runtime-version 3.9 \
  --functions-version 4 \
  --name dojogo-api-$(date +%s) \
  --storage-account dojogostorage$(date +%s) \
  --os-type Linux
```

**Note the Function App name** - you'll need this for the next steps!

### 6. Deploy the Code
Navigate to your API directory:
```bash
cd /Users/laeunkim/Dropbox/Dev/dojogo/dojogo/dojogo-api
```

Deploy the functions:
```bash
func azure functionapp publish YOUR_FUNCTION_APP_NAME
```

### 7. Configure Environment Variables
Set the database connection settings:
```bash
az functionapp config appsettings set \
  --name YOUR_FUNCTION_APP_NAME \
  --resource-group dojogo-rg \
  --settings \
  DB_HOST="dojogo-mysql-us-west2.mysql.database.azure.com" \
  DB_USER="klayon" \
  DB_PASSWORD="Zmfodyd4urAI" \
  DB_NAME="dojogo" \
  DB_PORT="3306"
```

### 8. Get Your Function App URL
```bash
az functionapp show --name YOUR_FUNCTION_APP_NAME --resource-group dojogo-rg --query "defaultHostName" --output tsv
```

This will return something like: `your-function-app-name.azurewebsites.net`

### 9. Update Your iOS App
Replace the placeholder in `APIService.swift`:
```swift
private let baseURL = "https://YOUR_FUNCTION_APP_NAME.azurewebsites.net/api"
```

## Alternative: Manual Deployment via Azure Portal

If CLI deployment fails, you can deploy manually:

1. **Go to Azure Portal** (portal.azure.com)
2. **Create Function App**:
   - Resource Group: Create new "dojogo-rg"
   - Function App name: "dojogo-api-[random]"
   - Runtime: Python 3.9
   - Region: West US 2
   - Plan: Consumption

3. **Deploy Code**:
   - In Function App → Deployment Center
   - Choose "External Git" or "ZIP Deploy"
   - Upload the `dojogo-api` folder

4. **Configure Settings**:
   - In Function App → Configuration → Application Settings
   - Add the database connection variables listed above

## Testing Your Deployment

Test each endpoint:
- `GET https://YOUR_FUNCTION_APP_NAME.azurewebsites.net/api/GetLeaderboard?type=total`
- Other endpoints require Auth0 tokens

## Next Steps
1. Deploy using one of the methods above
2. Update the iOS app with your actual Function App URL
3. Test the app end-to-end

Your Function App URL will be: `https://YOUR_FUNCTION_APP_NAME.azurewebsites.net/api`