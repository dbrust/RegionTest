#!/bin/bash

resourceGroup=sangroup
location=southafricanorth
regionone="southafricanorth"
regiontwo="southafricawest"

vnet=sanvnet
subnet=sansubnet
vmimage=UbuntuLTS
rhelvmname=redhat
adminLogin=sqladmin
adminPassword=adminPassword123
servername=server-$RANDOM
startip=0.0.0.0
endip=0.0.0.0
cosmosacct=southafricaacct
cosmosdb=sadb
premiumlrs=premiumlrs$RANDOM
standardgrs=standardgrs$RANDOM
standardlrs=standardlrs$RANDOM
standardragrs=standardragrs$RANDOM
myEventHubNamespace=$location$RANDOM
myEventHubName=eh$location
namespaceName=$location$RANDOM
batchStorage=$location$RANDOM
mySBName=$location$RANDOM
myBAName=$location$RANDOM
batchPoolID=mypool

# Do not change variables below
deployAll=true
deploySQL=false
deployMI=false
deployVNET=false
deployCosmos=false
deployVM=false
deployStorage=false
deployLB=false
deployAGateway=false
deleteRG=false
deployVMSS=false
deployEH=false
deploySB=false
deployBATCH=false

while getopts ":hbmpcvslatdefg" opt; do
    case ${opt} in
        h)
            echo "Usage:"
            echo "      ValidateRegion.sh [options]"
            echo ""
            echo "General Options:"
            echo "  -h              Show help."
            echo "  -b              Deploy SQL DB."
            echo "  -m              Deploy SQL MI."
            echo "  -p              Deploy VNET Peering."
            echo "  -c              Deploy CosmosDB."
            echo "  -v              Deploy VM's."
            echo "  -s              Deploy storage."
            echo "  -l              Deploy load balanced VMs."
            echo "  -a              Deploy Application Gateway."
            echo "  -t              Deploy VMSS."
            echo "  -e              Deploy EventHub."
            echo "  -f              Deploy ServiceBus."
            echo "  -g              Deploy Batch."
            echo "  -d              Delete the resource group $resourceGroup."
            exit 1
            ;;
        b)
            deploySQL=true
            deployAll=false
            ;;
        m)
            deployMI=true
            deployAll=false
            ;;
        p)
            deployVNET=true
            deployAll=false
            ;;
        c)
            deployCosmos=true
            deployAll=false
            ;;
        v)
            deployVM=true
            deployAll=false
            ;;
        s)
            deployStorage=true
            deployAll=false
            ;;
        l)
            deployLB=true
            deployAll=false
            ;;
        a)    
            deployAGateway=true
            deployAll=false
            ;;
        t)
            deployVMSS=true
            deployAll=false    
            ;;
        e)
            deployEH=true
            deployAll=false    
            ;;
        g)
            deploySB=true
            deployAll=false    
            ;;
        g)
            deployBATCH=true
            deployAll=false    
            ;;
        d)
            deleteRG=true
            ;;    
        \?) echo "Usage: ValidateRegion.sh [-h] [-d] [-m] [-p] [-c] [-v] [-s] [-l] [-a] [-d]"
            exit 1
            ;;
     esac
done    

if [ "$deleteRG" = true ]; then
    echo Deleteing Resource Group
    az group delete -n $resourceGroup --yes
    exit 1
fi
# Create a resource group
echo Creating Resource Group
az group create \
    --name $resourceGroup \
    --location $location

if [ "$deployAll" = true ] || [ "$deployBATCH" = true ]; then
    echo Creating storage for Batch
    az storage account create \
        --resource-group $resourceGroup \
        --name $batchStorage \
        --location $location \
        --sku Standard_LRS
fi

# Create a virtual network
echo Creating Vnet
az network vnet create \
    --resource-group $resourceGroup \
    --location $location \
    --name $vnet \
    --address-prefixes 10.0.0.0/16 \
    --subnet-name $subnet \
    --subnet-prefix 10.0.1.0/24


if [ "$deployAll" = true ] || [ "$deployStorage" = true ]; then
    # Create storage accounts
    echo Creating storage accounts
    az storage account create \
       --resource-group $resourceGroup \
       --location $location \
       --name $premiumlrs \
       --sku Premium_LRS

    az storage account create \
       --resource-group $resourceGroup \
       --location $location \
       --name $standardgrs \
       --sku Standard_GRS

    az storage account create \
       --resource-group $resourceGroup \
       --location $location \
       --name $standardlrs \
       --sku Standard_LRS

    az storage account create \
       --resource-group $resourceGroup \
       --location $location \
       --name $standardragrs \
       --sku Standard_RAGRS
fi

if [ "$deployAll" = true ] || [ "$deployLB" = true ]; then
    # Create a public IP address
    echo Creating publicIP
    az network public-ip create \
        --resource-group $resourceGroup \
        --name myPublicIP

    # Create an Azure Load Balancer
    echo Creating Load Balancer
    az network lb create \
        --resource-group $resourceGroup \
        --name myLoadBalancer \
        --public-ip-address myPublicIP \
        --frontend-ip-name myFrontEndPool \
        --backend-pool-name myBackEndPool

    # Creates an LB probe on port 80
    echo Creating LB Health Probe
    az network lb probe create \
        --resource-group $resourceGroup \
        --lb-name myLoadBalancer \
        --name myHealthProbe \
        --protocol tcp --port 80

    # Creates an LB rule for port 80
    az network lb rule create \
        --resource-group $resourceGroup \
        --lb-name myLoadBalancer \
        --name myLoadBalancerRuleWeb \
        --protocol tcp \
        --frontend-port 80 \
        --backend-port 80 \
        --frontend-ip-name myFrontEndPool \
        --backend-pool-name myBackEndPool \
        --probe-name myHealthProbe

    # Create two NAT rules for port 22
    for i in `seq 1 2`; do
        az network lb inbound-nat-rule create \
            --resource-group $resourceGroup \
            --lb-name myLoadBalancer \
            --name myLoadBalancerRuleSSH$i \
            --protocol tcp \
            --frontend-port 422$i \
            --backend-port 22 \
            --frontend-ip-name myFrontEndPool
    done

    # Create a network security group
    echo Creating NSG
    az network nsg create \
        --resource-group $resourceGroup \
        --name myNetworkSecurityGroup

    # Create a network security group rule for port 22
    az network nsg rule create --resource-group $resourceGroup --nsg-name myNetworkSecurityGroup --name myNetworkSecurityGroupRuleSSH \
        --protocol tcp --direction inbound --source-address-prefix '*' --source-port-range '*'  \
        --destination-address-prefix '*' --destination-port-range 22 --access allow --priority 1000

    # Create a network security group rule for port 80
    az network nsg rule create --resource-group $resourceGroup --nsg-name myNetworkSecurityGroup --name myNetworkSecurityGroupRuleHTTP \
        --protocol tcp --direction inbound --priority 1001 --source-address-prefix '*' --source-port-range '*' \
        --destination-address-prefix '*' --destination-port-range 80 --access allow --priority 2000

    # Create two virtual network cards and associate with public IP address and NSG
    echo Creating Network Cards
    for i in `seq 1 2`; do
        az network nic create \
            --resource-group $resourceGroup --name myNic$i \
        --vnet-name $vnet --subnet $subnet \
        --network-security-group myNetworkSecurityGroup --lb-name myLoadBalancer \
        --lb-address-pools myBackEndPool --lb-inbound-nat-rules myLoadBalancerRuleSSH$i
    done

    # Create an availability set
    az vm availability-set create \
        --resource-group $resourceGroup \
        --name myAvailabilitySet \
        --platform-fault-domain-count 2 \
        --platform-update-domain-count 2

    # Create two virtual machines, this creates SSH keys if not present
    echo Creating VMs 
    for i in `seq 1 2`; do
        az vm create \
            --resource-group $resourceGroup \
            --name myVM$i \
            --availability-set myAvailabilitySet \
            --nics myNic$i \
            --image $vmimage \
            --generate-ssh-keys
    done

    # Configure the VMs
    for i in `seq 1 2`; do
    az vm extension set \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --name CustomScript \
        --vm-name myVM$i \
        --resource-group $resourceGroup \
        --no-wait \
        --settings ./script-config.json
    done
fi

#if [ "$deployAll" = true ] || [ "$deployMI" = true ]; then
#    echo Creating SQL MI
#    az network vnet subnet create \
#        --name sqlmiSubnet \
#        --resource-group $resourceGroup \
#        --vnet-name $vnet \
#        --address-prefix 10.0.4.0/24
#
#        az sql mi create \
#           --resource-group $resourceGroup \
#           --name mysqlmi \
#           --location $location \
#           --assign-identity \
#           --admin-user sqlm1admin \
#           --admin-password sqlm1passw0rd \
#           --subnet sqlmiSubnet \
#           --vnet-name $vnet 
#fi           


if [ "$deployAll" = true ] || [ "$deploySQL" = true ]; then
    echo Creating SQL DB
    az sql server create \
       --name $servername \
       --resource-group $resourceGroup \
       --location $location \
       --admin-user $adminLogin \
       --admin-password $adminPassword

    az sql server firewall-rule create \
       --resource-group $resourceGroup \
       --server $servername \
       -n AllowIPs \
       --start-ip-address $startip \
       --end-ip-address $endip

    az sql db create \
       --resource-group $resourceGroup \
       --server $servername \
       --name testDatabase \
       --service-objective S0
fi       

if [ "$deployAll" = true ] || [ "$deployCosmos" = true ]; then
    # Create Cosmos DB
    echo Creating Cosmos DB Service
    az cosmosdb create \
        --resource-group $resourceGroup \
        --name $cosmosacct \
        --kind GlobalDocumentDB \
        --locations $regionone=0 $regiontwo=1 \
        --default-consistency-level "Session" \
        --enable-multiple-write-locations true

    echo Creating Cosmos DB database
    az cosmosdb database create \
        --resource-group $resourceGroup \
        --name $cosmosacct \
        --db-name $cosmosdb

    az cosmosdb collection create \
        --resource-group $resourceGroup \
        --name $cosmosacct \
        --db-name $cosmosdb \
        --collection-name sacollection \
        --partition-key-path /mypartitionkey \
        --throughput 1000
fi

if [ "$deployAll" = true ] || [ "$deployAGateway" = true ]; then
    echo Creating Application Gateway
    az network vnet subnet create \
        --name gatewaySubnet \
        --resource-group $resourceGroup \
        --vnet-name $vnet \
        --address-prefix 10.0.2.0/24

    az network vnet subnet create \
        --name backendSubnet \
        --resource-group $resourceGroup \
        --vnet-name $vnet \
        --address-prefix 10.0.3.0/24

    az network public-ip create \
        --resource-group $resourceGroup \
        --name appGatewayIP

    for i in `seq 1 2`; do
        az network nic create \
            --resource-group $resourceGroup --name appGatewayNic$i \
            --vnet-name $vnet --subnet backendSubnet 
        
        az vm create \
           --resource-group $resourceGroup \
           --name appGatewayVM$i \
           --nics appGatewayNic$i \
           --image $vmimage \
           --generate-ssh-keys \
           --custom-data cloud-init.txt
    done
fi

if [ "$deployAll" = true ] || [ "$deployVNET" = true ]; then
    # Vnet peering
    echo Creating Vnet Peering
    az network vnet create \
           --name vnetPeeringOne \
           --resource-group $resourceGroup \
           --address-prefixes 10.1.0.0/16 \
           --subnet-name subnetPeeringOne \
           --subnet-prefix 10.1.0.0/24

    az network vnet create \
           --name vnetPeeringTwo \
           --resource-group $resourceGroup \
           --address-prefixes 10.2.0.0/16 \
           --subnet-name subnetPeeringOne \
           --subnet-prefix 10.2.0.0/24

    vNet1Id=$(az network vnet show \
                --resource-group $resourceGroup \
                --name vnetPeeringOne \
                --query id --out tsv)

    vNet2Id=$(az network vnet show \
                --resource-group $resourceGroup \
                --name vnetPeeringTwo \
                --query id --out tsv)

    az network vnet peering create \
           --resource-group $resourceGroup \
           --name myPeerOneToMyPeerTwo \
           --vnet-name vnetPeeringOne \
           --remote-vnet-id $vNet2Id \
           --allow-vnet-access

    az network vnet peering create \
           --resource-group $resourceGroup \
           --name myPeerTwoToMyPeerOne \
           --vnet-name vnetPeeringTwo \
           --remote-vnet-id $vNet1Id \
           --allow-vnet-access

    az network vnet peering show \
           --name myPeerOneToMyPeerTwo \
           --resource-group $resourceGroup \
           --vnet-name vnetPeeringOne \
           --query peeringState

    az network vnet peering show \
           --name myPeerTwoToMyPeerOne \
           --resource-group $resourceGroup \
           --vnet-name vnetPeeringTwo \
           --query peeringState

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name vmPeerOne \
       --image $vmimage \
       --vnet-name vnetPeeringOne \
       --subnet subnetPeeringOne \
       --generate-ssh-keys \
       --no-wait

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name vmPeerTwo \
       --image $vmimage \
       --vnet-name vnetPeeringTwo \
       --subnet subnetPeeringOne \
       --generate-ssh-keys

    address1=$(az network nic show --name appGatewayNic1 --resource-group $resourceGroup --query  ipConfigurations[0].privateIpAddress --output tsv)
    address2=$(az network nic show --name appGatewayNic2 --resource-group $resourceGroup --query  ipConfigurations[0].privateIpAddress --output tsv)

    az network application-gateway create \
           --name myAppGateway \
           --location $location \
           --resource-group $resourceGroup \
           --capacity 2 \
           --sku Standard_Medium \
           --http-settings-cookie-based-affinity Enabled \
           --public-ip-address appGatewayIP \
           --vnet-name $vnet \
           --subnet gatewaySubnet \
           --servers "$address1" "$address2"
fi


if [ "$deployAll" = true ] || [ "$deployVM" = true ]; then
    # Create VM families       
        echo Creating VM families
        az vm create \
           --resource-group $resourceGroup \
       --location $location \
       --name StandardAV1 \
       --image $vmimage \
       --public-ip-address-dns-name standardav1 \
       --size Standard_A1 \
       --generate-ssh-keys

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name StandardAV2 \
       --image $vmimage \
       --public-ip-address-dns-name standardav2 \
       --size Standard_A1_v2 \
       --generate-ssh-keys

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name StandardDV2 \
       --image $vmimage \
       --size Standard_D1_v2 \
       --public-ip-address-dns-name standarddv2 \
       --generate-ssh-keys

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name StandardE \
       --image $vmimage \
       --size Standard_E2_v3 \
       --public-ip-address-dns-name standarde \
       --generate-ssh-keys

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name StandardB \
       --image $vmimage \
       --size Standard_B1ms \
       --public-ip-address-dns-name standardb \
       --generate-ssh-keys

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name StandardF \
       --image $vmimage \
       --size Standard_F2s \
       --public-ip-address-dns-name standardf \
       --generate-ssh-keys

    # Create Windows and Redhat VMs
    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name windoze \
       --image win2016datacenter \
       --public-ip-address-dns-name windoze \
       --size Standard_D1_V2 \
       --admin-username azureuser \
       --admin-password azureUserPW123

    az vm create \
       --resource-group $resourceGroup \
       --location $location \
       --name $rhelvmname \
       --image RHEL \
       --public-ip-address-dns-name redhat \
       --size Standard_D1_V2 \
       --generate-ssh-keys

    echo Creating SQL VM
    az vm create \
        --resource-group $resourceGroup \
        --location $location \
        --name sqlvm \
        --image MicrosoftSQLServer:SQL2019-WS2016:SQLDEV:15.0.190108 \
        --public-ip-address-dns-name winsql \
        --admin-username azureuser \
        --admin-password azureUserPW123
fi

if [ "$deployAll" = true ] || [ "$deployVMSS" = true ]; then
    echo Creating VMSS
    az vmss create \
        --resource-group $resourceGroup \
        --name testScaleSet \
        --image $vmimage \
        --upgrade-policy-mode automatic \
        --admin-username  azureuser \
        --generate-ssh-keys

    az vmss extension set \
        --resource-group $resourceGroup \
        --publisher Microsoft.Azure.Extensions \
        --version 2.0 \
        --name CustomScript \
        --vmss-name testScaleSet \
        --settings '{"fileUris":["https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate_nginx.sh"],"commandToExecute":"./automate_nginx.sh"}'

    az network lb rule create \
        --resource-group $resourceGroup \
        --name vmssLoadBalancerRuleWeb \
        --lb-name testScaleSetLB \
        --backend-pool-name testScaleSetLBBEPool \
        --backend-port 80 \
        --frontend-ip-name loadBalancerFrontEnd \
        --frontend-port 80 \
        --protocol tcp
fi

if [ "$deployAll" = true ] || [ "$deployEH" = true ]; then
    echo Creating Event Hub
    az eventhubs namespace create \
        --name $myEventHubNamespace \
        --resource-group $resourceGroup \
        -l $location

    az eventhubs eventhub create \
        --name $myEventHubName \
        --resource-group $resourceGroup \
        --namespace-name $myEventHubNamespace
fi

if [ "$deployAll" = true ] || [ "$deploySB" = true ]; then
    echo Creating Service Bus
    az servicebus namespace create \
        --resource-group $resourceGroup \
        --name $namespaceName \
        --location $location

    az servicebus queue create \
        --resource-group $resourceGroup \
        --namespace-name $namespaceName \
        --name $mySBName
fi

if [ "$deployAll" = true ] || [ "$deployBATCH" = true ]; then
    echo Creating Batch

    az batch account create \
        --name $myBAName \
        --resource-group $resourceGroup \
        --location $location
    
    az batch account login \
        --name $myBAName \
        --resource-group $resourceGroup \
        --shared-key-auth

    az batch account set \
        --resource-group $resourceGroup \
        --name $myBAName \
        --storage-account $batchStorage
    
    az batch account keys list \
        --resource-group $resourceGroup \
        --name $myBAName \
    
    az batch pool create \
        --id $batchPoolID \
        --vm-size Standard_A1_v2 \
        --target-dedicated-nodes 2 \
        --image canonical:ubuntuserver:16.04-LTS \
        --node-agent-sku-id "batch.node.ubuntu 16.04"
fi

# Create an Azure Container Instance
#echo Creating an Azure Container Instance
#
#az container create \
#--resource-group $resourceGroup \
#--name containertest \
#--image microsoft/aci-helloworld \
#--dns-name-label container-test \
#--ports 80
#
# Create AKS cluster
#echo Creating AKS 
#az aks create \
#--resource-group $resourceGroup \
#--name testAKSCluster \
#--node-count 1 \
#--enable-addons monitoring \
#--generate-ssh-keys

#echo To validate AKS installation, you must first install the kubectl in your environment.  If using Cloud Shell, it is already there:
#echo sudo az aks install-cli
#echo after installed, run the following to validate that there is a node ready:
#echo kubectl get nodes
echo
if [ "$deployAll" = true ] || [ "$deployLB" = true ]; then
    loadBalancerAddress=$(az network public-ip show --resource-group $resourceGroup -n myPublicIP --query [ipAddress] --output tsv)   
    echo Load Balancer Address: $loadBalancerAddress
    echo
    echo To log into load balanced VM:
    echo ssh $LOGNAME@$loadBalancerAddress -p 4222
fi    
if [ "$deployAll" = true ] || [ "$deployVM" = true ]; then
    echo
    echo To log into Redhat VM:
    echo ssh $LOGNAME@$rhelvmname.$location.cloudapp.azure.com
    echo
    echo To log into Windows VM:
    echo Log into portal, navigate to the Windows VM, and select Connect
    echo Login: azureuser PW: azureUserPW123
fi    
if [ "$deployAll" = true ] || [ "$deployAGateway" = true ]; then
    appGatewayAddress=$(az network public-ip show --resource-group $resourceGroup -n appGatewayIP --query [ipAddress] --output tsv)
    echo
    echo App Gateway IP Address: $appGatewayAddress
    echo
fi    
if [ "$deployAll" = true ] || [ "$deployVMSS" = true ]; then
    vmssAddress=$(az network public-ip show --resource-group $resourceGroup -n testScaleSetLBPublicIP --query [ipAddress] --output tsv)   
    echo VMSS Load Balancer Address: $vmssAddress
    echo
fi    
if [ "$deployAll" = true ] || [ "$deployEH" = true ]; then
    connectionString=$(az servicebus namespace authorization-rule keys list --resource-group $resourceGroup --namespace-name $namespaceName --name RootManageSharedAccessKey --query primaryConnectionString --output tsv)
    echo EventHub connection string: $connectionString
    echo
fi
if [ "$deployAll" = true ] || [ "$deployBATCH" = true ]; then
    echo Batch Pool Allocation State:
    az batch pool show --pool-id $batchPoolID --query "allocationState"
    echo
fi

az vm list -g $resourceGroup --show-details --output table
