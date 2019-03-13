#!/bin/bash

resourceGroup=sanrgroup
vnet=sanvnet
subnet=sansubnet
location=southafricanorth
servername=server-$RANDOM
adminLogin=sqladmin
adminPassword=adminPassword123
startip=0.0.0.0
endip=0.0.0.0

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

