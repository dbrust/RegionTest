
#!/bin/bash

resourceGroup=eastusvmssbrust
location=eastus
vmimage=UbuntuLTS
    
# Create a resource group
echo Creating Resource Group
az group create \
    --name $resourceGroup \
    --location $location

echo Creating VMSS
az vmss create \
    --resource-group $resourceGroup \
    --name testScaleSet \
    --image $vmimage \
    --upgrade-policy-mode automatic \
    --admin-username  azureuser \
    --generate-ssh-keys

echo Running vmss extension
az vmss extension set \
    --resource-group $resourceGroup \
    --publisher Microsoft.Azure.Extensions \
    --version 2.0 \
    --name CustomScript \
    --vmss-name testScaleSet \
    --settings '{"fileUris":["https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate_nginx.sh"],"commandToExecute":"./automate_nginx.sh"}'

echo Adding lb rule    
az network lb rule create \
    --resource-group $resourceGroup \
    --name vmssLoadBalancerRuleWeb \
    --lb-name testScaleSetLB \
    --backend-pool-name testScaleSetLBBEPool \
    --backend-port 80 \
    --frontend-ip-name loadBalancerFrontEnd \
    --frontend-port 80 \
    --protocol tcp
