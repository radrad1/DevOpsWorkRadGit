param (
   [string] $AzureWebsiteName,
   [string] $From,
   [string] $To
)
Switch-AzureWebsiteSlot -Name $AzureWebsiteName -Slot1 $From -Slot2 $To -Force -Verbose