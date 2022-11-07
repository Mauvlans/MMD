<# ***************************************************************************
#
# Purpose: Manually Register your Cloud PCs with Microsoft Managed Desktop
#
# ------------- DISCLAIMER -------------------------------------------------
# This script code is provided as is with no guarantee or waranty concerning
# the usability or impact on systems and may be used, distributed, and
# modified in any way provided the parties agree and acknowledge the 
# Microsoft or Microsoft Partners have neither accountabilty or 
# responsibility for results produced by use of this script.
#
# Microsoft will not provide any support through any means.
# ------------- DISCLAIMER -------------------------------------------------
#
# ***************************************************************************
#>

#Install-Module Az.Accounts -allowclobber -force
#Install-Module AzureAD -allowclobber -force

param(
    [Parameter(Mandatory = $true)] [String] $Global:resourceGroup
)

$Global:CusmPartnerAPIUrl = "https://mmdls.microsoft.com/api/v1.0/devices/register/takeover"
#$Global:CusmPartnerAPIUrl = "https://mmdls.microsoft.com/api/v1.0/devices/register/takeover?ring=Test"

Write-Host Importing Az.Accounts
Import-Module Az.Accounts -Force

Write-Host Importing AzureAD
Import-Module AzureAD -Force

Write-Host "Connect to AzAccount Azure Service"
Connect-AzAccount

Write-Host "Connect to Azure AD Azure Service"
Connect-AzureAD

function PostRegisterRequest {

    Write-Host "Getting Access Token for API"
    # Get token for MWAAS APIs
    $token = Get-AzAccessToken -ResourceUrl "c9d36ed4-91b3-4c87-b8d7-68d92826c96c"

    #construct the auth header
    $header = @{
        'Content-Type'  = 'application/json'
        'Authorization' = "Bearer" + " " + "$($token.token)"
    }

    Write-Host "Invoking API for device regestration"
    # Use Customer API to add device to autopilot
    $APIResponse = Invoke-RestMethod -Uri $Global:CusmPartnerAPIUrl -Method POST -Headers $header -Body $Global:deviceList

    if ($registrationStatus.requestStatus = "Completed") {

        $registrationStatus.requestStatus | Out-String | Write-Host
        
    }

    if ($apiResponse.problematicDevices.errorCode -eq "AlreadyRegistered") {
	
        Write-Host "VM $vm already registered"
        $apiResponse.problematicDevices | Out-String | Write-Host
	
    }

    elseif (($null -ne $apiResponse.problematicDevices.errorCode) -and ($apiResponse.problematicDevices.errorCode -ne "AlreadyRegistered")) {
	
        Write-Host "Registration found a problem, VM $vm is not register"
        $apiResponse.problematicDevices | Out-String | Write-Host
	
    }

}

function main {

    # getting all VM's in a given Resource Group
    $vmLookup = Get-AzVM -ResourceGroupName $Global:resourceGroup
    
    # Calling out VM Name for all VM's in Resource Group 
    $vmIds = $vmLookup.Name

    # Loop action for each VM found in Resource Group
    foreach ($vm in $vmIds) { 

        # Query VM by Name from Azure AD
        Write-Host "Query Azure AD for Device $vm"
        $vmId = get-azureADDevice -SearchString $vm 

        # Generate varible by calling out Device ID from Azure AD Object
        $aadDeviceID = $vmId.DeviceId
        Write-Host "The Device ID for $vm is $aadDeviceID"

        # Define the required parameters for takeover
        $Global:deviceList = @"
{
  "deviceList": [
    {
      "aadDeviceId": "$aadDeviceID",
      "plan": "Premium",
      "persona": "All"
    }
  ]
}
"@

        PostRegisterRequest

    }
}


main

