#!/bin/bash

resourceGroup=peertestsanw
location=southafricanorth
location2=southafricawest
vmimage=UbuntuLTS

# Create a resource group
echo Creating Resource Group
az group create \
    --name $resourceGroup \
    --location $location
    
echo Creating Vnet1 
az network vnet create \
       --name vnetOne \
       --resource-group $resourceGroup \
       --location $location \
       --address-prefixes 10.5.0.0/16 \
       --subnet-name subnetOne \
       --subnet-prefix 10.5.0.0/24

echo Creating Vnet2 
az network vnet create \
       --name vnetTwo \
       --resource-group $resourceGroup \
       --location $location2 \
       --address-prefixes 10.6.0.0/16 \
       --subnet-name subnetOne \
       --subnet-prefix 10.6.0.0/24

vNet1Id=$(az network vnet show \
            --resource-group $resourceGroup \
            --name vnetOne \
            --query id --out tsv)

vNet2Id=$(az network vnet show \
            --resource-group $resourceGroup \
            --name vnetTwo \
            --query id --out tsv)

echo Creating vnet peering 1
az network vnet peering create \
       --resource-group $resourceGroup \
       --name myPeerOneToMyPeerTwo \
       --vnet-name vnetOne \
       --remote-vnet-id $vNet2Id \
       --allow-vnet-access \
       --verbose

echo Creating vnet peering 2
az network vnet peering create \
       --resource-group $resourceGroup \
       --name myPeerTwoToMyPeerOne \
       --vnet-name vnetTwo \
       --remote-vnet-id $vNet1Id \
       --allow-vnet-access \
       --verbose

echo Creating VM1
az vm create \
   --resource-group $resourceGroup \
   --location $location \
   --name myVMSAN \
   --image $vmimage \
   --size Standard_D2_v2 \
   --vnet-name vnetOne \
   --subnet subnetOne \
   --generate-ssh-keys \

echo Creating VM2
az vm create \
   --resource-group $resourceGroup \
   --location $location2 \
   --name myVMSAW \
   --image $vmimage \
   --size Standard_D2_v2 \
   --vnet-name vnetTwo \
   --subnet subnetOne \
   --generate-ssh-keys

peerstate1=$(az network vnet peering show \
       --name myPeerOneToMyPeerTwo \
       --resource-group $resourceGroup \
       --vnet-name vnetOne \
       --query peeringState)

peerstate2=$(az network vnet peering show \
       --name myPeerTwoToMyPeerOne \
       --resource-group $resourceGroup \
       --vnet-name vnetTwo \
       --query peeringState)

echo Peerstate from Vnet1 to Vnet2: $peerstate1
echo Peerstate from Vnet2 to Vnet1: $peerstate2
