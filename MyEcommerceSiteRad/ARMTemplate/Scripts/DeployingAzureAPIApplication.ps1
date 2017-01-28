param (#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage
 
Param(
    [string] $ResourceGroupLocation = '[Location]',
    [string] $ResourceGroupName = '[Resource Group Name',
    [string] $WebApiPackage = '[Full path to pacakge]',
    [string] $TemplateFile = '[Path to the template]',
    [string] $TemplateParametersFile = 'Path to the parameters file]',
    [string] $DeployContainer = 'deployment'
)
 
Import-Module Azure -ErrorAction SilentlyContinue
Set-StrictMode -Version 3   
 
#Login to the Azure Resource Management Account
Login-AzureRmAccount
 
#Construct Azure Resource Manager parameters
$OptionalParameters = New-Object -TypeName Hashtable
$DateFormat = Get-Date -Format "yyyyMMdd-HHmm"
$FileName = "package-" + $dateFormat + ".zip"
$TemplateFile = [System.IO.Path]::Combine($PSScriptRoot, $TemplateFile)
$TemplateParametersFile = [System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile)
 
#Construct deployment parameters
$DeployStorageAccountName = $ResourceGroupName.ToLowerInvariant() + 'deployment'
$DeployStorageAccountName = $DeployStorageAccountName -replace '-'
 
 
#Create Azure Resource Group
Write-Host "Creating Azure Resource Group: " $ResourceGroupName " in " $ResourceGroupLocation -ForegroundColor Green
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Force -ErrorAction Stop 
 
#Create Azure Storage Account for the deployment of the resources
Write-Host "Creating Azure Storage Account in Resource Group : " $ResourceGroupName " named " $DeployStorageAccountName -ForegroundColor Green
New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $DeployStorageAccountName -Type "Standard_LRS" -Location $ResourceGroupLocation
 
#Create storage container for the deployment files
Write-Host "Creating storage container for the deployment files named: "  $DeployContainer -ForegroundColor Green
$StorageAccountContext = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $DeployStorageAccountName }).Context
$StorageContainer = Get-AzureStorageContainer -Name $DeployContainer -Context $StorageAccountContext -ErrorAction SilentlyContinue
if($StorageContainer -eq $null){
    New-AzureStorageContainer -Name $DeployContainer -Context $StorageAccountContext
}
 
#Adding the package to the container
Write-Host "Adding the deployment package to the container with the name: " $FileName -ForegroundColor Green
Set-AzureStorageBlobContent -File $WebApiPackage -Blob $FileName -Container 'deployment' -Context $StorageAccountContext -Force
 
#Setting the optional parameters for the deployment file
$ArtifactsLocation = $StorageAccountContext.BlobEndPoint + $DeployContainer
$ArtifactsLocationSasToken = New-AzureStorageContainerSASToken -Container $DeployContainer -Context $StorageAccountContext -Permission r -ExpiryTime (Get-Date).AddHours(4)
$ArtifactsLocationSasToken = ConvertTo-SecureString $ArtifactsLocationSasToken -AsPlainText -Force
 
$OptionalParameters = New-Object -TypeName Hashtable
$OptionalParameters['_artifactsLocation'] = $ArtifactsLocation
$OptionalParameters['_artifactsLocationSasToken'] = $ArtifactsLocationSasToken
$OptionalParameters['_packageFileName'] = $FileName
 
#Deploying resources with the resource management file
Write-Host "Deploying resources to the Resource Group: " $ResourceGroupName -ForegroundColor Green
New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $TemplateFile `
                                   -TemplateParameterFile $TemplateParametersFile `
                                   @OptionalParameters `
                                   -Force
