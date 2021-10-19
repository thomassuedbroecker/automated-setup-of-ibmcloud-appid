#!/bin/bash

# **************** Global variables set as default values

export RESOURCE_GROUP="Default"
export REGION="us-south"
export FRONTEND_NAME="myexamplefrontend"
export FRONTEND_URL="https://myexamplefrontend.url"

# AppID Service
export YOUR_SERVICE_FOR_APPID=appid-example
export APPID_SERVICE_KEY_NAME=appid-example-key
export SERVICE_PLAN="lite"
export APPID_SERVICE_NAME="appid"
export APPID_SERVICE_KEY_ROLE="Manager"
export TENANTID=""
export MANAGEMENTURL=""
export APPLICATION_DISCOVERYENDPOINT=""

# AppID User
export USER_IMPORT_FILE="appid-configs/user-import.json"
export USER_EXPORT_FILE="appid-configs/user-export.json"
export ENCRYPTION_SECRET="12345678"

# AppID Application configuration
export ADD_APPLICATION="appid-configs/add-application.json"
export ADD_SCOPE="appid-configs/add-scope.json"
export ADD_ROLE="appid-configs/add-roles.json"
export ADD_REDIRECT_URIS="appid-configs/add-redirecturis.json"
export ADD_UI_TEXT="appid-configs/add-ui-text.json"
export ADD_IMAGE="appid-images/logo.png"
export ADD_COLOR="appid-configs/add-ui-color.json"
export APPLICATION_CLIENTID=""
export APPLICATION_TENANTID=""
export APPLICATION_OAUTHSERVERURL=""

# **********************************************************************************
# Functions definition
# **********************************************************************************

function configureIBMCloudTarget() {
  ibmcloud target -r $REGION
  ibmcloud target -g $RESOURCE_GROUP
}

# **** AppID ****

function createAppIDService() {
    ibmcloud target -g $RESOURCE_GROUP
    ibmcloud target -r $REGION
    # Create AppID service
    ibmcloud resource service-instance-create $YOUR_SERVICE_FOR_APPID $APPID_SERVICE_NAME $SERVICE_PLAN $REGION
    # Create a service key for the service
    ibmcloud resource service-key-create $APPID_SERVICE_KEY_NAME $APPID_SERVICE_KEY_ROLE --instance-name $YOUR_SERVICE_FOR_APPID
    # Get the tenantId of the AppID service key
    TENANTID=$(ibmcloud resource service-keys --instance-name $YOUR_SERVICE_FOR_APPID --output json | grep "tenantId" | awk '{print $2;}' | sed 's/"//g')
    echo "Tenant ID: $TENANTID"
    # Get the managementUrl of the AppID from service key
    MANAGEMENTURL=$(ibmcloud resource service-keys --instance-name $YOUR_SERVICE_FOR_APPID --output json | grep "managementUrl" | awk '{print $2;}' | sed 's/"//g' | sed 's/,//g')
    echo "Management URL: $MANAGEMENTURL"
}

function configureAppIDInformation(){

    #****** Set identity providers
    echo ""
    echo "-------------------------"
    echo " Set identity providers"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-custom.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/custom)
    echo ""
    echo "-------------------------"
    echo "Result custom: $result"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-facebook.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/facebook)
    echo ""
    echo "-------------------------"
    echo "Result facebook: $result"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-google.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/google)
    echo ""
    echo "-------------------------"
    echo "Result google: $result"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./appid-configs/idps-clouddirectory.json -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/idps/cloud_directory)
    echo ""
    echo "-------------------------"
    echo "Result cloud directory: $result"
    echo "-------------------------"
    echo ""

    #****** Add application ******
    echo ""
    echo "-------------------------"
    echo " Create application"
    echo "-------------------------"
    echo ""
    sed "s+FRONTENDNAME+$FRONTEND_NAME+g" ./appid-configs/add-application-template.json > ./$ADD_APPLICATION
    result=$(curl -d @./$ADD_APPLICATION -H "Content-Type: application/json" -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/applications)
    rm -f ./$ADD_APPLICATION
    echo "-------------------------"
    echo "Result application: $result"
    echo "-------------------------"
    APPLICATION_CLIENTID=$(echo $result | sed -n 's|.*"clientId":"\([^"]*\)".*|\1|p')
    APPLICATION_TENANTID=$(echo $result | sed -n 's|.*"tenantId":"\([^"]*\)".*|\1|p')
    APPLICATION_OAUTHSERVERURL=$(echo $result | sed -n 's|.*"oAuthServerUrl":"\([^"]*\)".*|\1|p')
    APPLICATION_DISCOVERYENDPOINT=$(echo $result | sed -n 's|.*"discoveryEndpoint":"\([^"]*\)".*|\1|p')
    echo "ClientID: $APPLICATION_CLIENTID"
    echo "TenantID: $APPLICATION_TENANTID"
    echo "oAuthServerUrl: $APPLICATION_OAUTHSERVERURL"
    echo "discoveryEndpoint: $APPLICATION_DISCOVERYENDPOINT"
    echo ""

    #****** Add scope ******
    echo ""
    echo "-------------------------"
    echo " Add scope"
    echo "-------------------------"
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./$ADD_SCOPE -H "Content-Type: application/json" -X PUT -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/applications/$APPLICATION_CLIENTID/scopes)
    echo "-------------------------"
    echo "Result scope: $result"
    echo "-------------------------"
    echo ""

    #****** Add role ******
    echo "-------------------------"
    echo " Add role"
    echo "-------------------------"
    #Create file from template
    sed "s+APPLICATIONID+$APPLICATION_CLIENTID+g" ./appid-configs/add-roles-template.json > ./$ADD_ROLE
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    #echo $OAUTHTOKEN
    result=$(curl -d @./$ADD_ROLE -H "Content-Type: application/json" -X POST -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/roles)
    rm -f ./$ADD_ROLE
    echo "-------------------------"
    echo "Result role: $result"
    echo "-------------------------"
    echo ""
 
    #****** Import cloud directory users ******
    echo ""
    echo "-------------------------"
    echo " Cloud directory import users"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    result=$(curl -d @./$USER_IMPORT_FILE -H "Content-Type: application/json" -X POST -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/cloud_directory/import?encryption_secret=$ENCRYPTION_SECRET)
    echo "-------------------------"
    echo "Result import: $result"
    echo "-------------------------"
    echo ""

    #******* Configure ui text  ******
    echo ""
    echo "-------------------------"
    echo " Configure ui text"
    echo "-------------------------"
    echo ""
    sed "s+FRONTENDNAME+$FRONTEND_NAME+g" ./appid-configs/add-ui-text-template.json > ./$ADD_UI_TEXT
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    echo "PUT url: $MANAGEMENTURL/config/ui/theme_txt"
    #result=$(curl -d @./$ADD_UI_TEXT -H "Content-Type: application/json" -X PUT -v -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/ui/theme_text)
    result=$(curl -d @./$ADD_UI_TEXT -H "Content-Type: application/json" -X PUT -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/ui/theme_text)
    rm -f $ADD_UI_TEXT
    echo "-------------------------"
    echo "Result import: $result"
    echo "-------------------------"
    echo ""

    #******* Configure ui color  ******
    echo ""
    echo "-------------------------"
    echo " Configure ui color"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    echo "PUT url: $MANAGEMENTURL/config/ui/theme_color"
    result=$(curl -d @./$ADD_COLOR -H "Content-Type: application/json" -X PUT -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/ui/theme_color)
    echo "-------------------------"
    echo "Result import: $result"
    echo "-------------------------"
    echo ""

    #******* Configure ui image  ******
    echo ""
    echo "-------------------------"
    echo " Configure ui image"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    echo "POST url: $MANAGEMENTURL/config/ui/media?mediaType=logo"
    result=$(curl -F "file=@./$ADD_IMAGE" -H "Content-Type: multipart/form-data" -X POST -v -H "Authorization: Bearer $OAUTHTOKEN" "$MANAGEMENTURL/config/ui/media?mediaType=logo")
    echo "-------------------------"
    echo "Result import: $result"
    echo "-------------------------"
    echo ""
}

function addRedirectURIAppIDInformation(){

    #****** Add redirect uris ******
    echo ""
    echo "-------------------------"
    echo " Add redirect uris"
    echo "-------------------------"
    echo ""
    OAUTHTOKEN=$(ibmcloud iam oauth-tokens | awk '{print $4;}')
    echo "Redirect URL: $FRONTEND_URL"
    #Create file from template
    sed "s+APPLICATION_REDIRECT_URL+$FRONTEND_URL+g" ./appid-configs/add-redirecturis-template.json > ./$ADD_REDIRECT_URIS
    result=$(curl -d @./$ADD_REDIRECT_URIS -H "Content-Type: application/json" -X PUT -H "Authorization: Bearer $OAUTHTOKEN" $MANAGEMENTURL/config/redirect_uris)
    rm -f ./$ADD_REDIRECT_URIS
    echo "-------------------------"
    echo "Result redirect uris: $result"
    echo "-------------------------"
    echo ""
}

# **********************************************************************************
# Execution
# **********************************************************************************

echo "************************************"
echo " CLI config"
echo "************************************"

createAppIDService

echo "************************************"
echo " AppID creation"
echo "************************************"

createAppIDService

echo "************************************"
echo " AppID configuration"
echo "************************************"

configureAppIDInformation

echo "************************************"
echo " AppID add redirect URI"
echo "************************************"

addRedirectURIAppIDInformation

echo "************************************"
echo " AppID URLs and example URL"
echo "************************************"
echo " - oAuthServerUrl   : $APPLICATION_OAUTHSERVERURL"
echo " - discoveryEndpoint: $APPLICATION_DISCOVERYENDPOINT"
echo " - Frontend         : $FRONTEND_URL"

