#!/bin/bash

print_usage() {
  echo "sh AKS-FlexGWInstall.sh [arguments] [options]"
  echo " "
  echo "arguments:"
  echo "--flexName                specify the Flex Gateway Name to register"
  echo "--flexToken               specify the token to register the Flex Gateway (Obtained from AP Control Plane)"
  echo "--orgId                   specify the OrgID where to register and iinstall the Flex Gateway"

  echo " "
  echo "options:"
  echo "-h                        Print this message"
  echo "--refreshFlexImage        When specified, the script will try to pull the latest image from Docker hub (this requires a predefined Azure Container Registry)"
  echo "--aksClusterName          Name of the existing AKS cluster where Flex will be installed. Use it only when --refreshFlexImage is set"
  echo "--aksClusterRgName        Name of the existing Resource Group where the AKS cluster was created. Use it only when --refreshFlexImage is set"
  echo "--acrName                 Name of the existing Azure Container Registry (ACR). Use it only when --refreshFlexImage is set"  
  echo "--printRegistrationFile   When specified, the container logs will print the registration.yaml file content. This is useful to register additional replicas without having to share persistent volumes between containers"
}

for i in "$@" 
do
case $i in
    -h)
      print_usage
      exit 0
      ;;
    --flexGwName*)
      flexGatewayName=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    --flexGwToken*)
      flexGatewayToken=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;
    --orgId*)
      flexGatewayOrg=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;    
    --refreshFlexImage)
      REFRESH_IMAGE=Y
      shift
      ;;    
    --aksClusterName*)
      k8sCluster=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;    
    --aksClusterRgName*)
      k8sClusterRg=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;;   
    --acrName*)
      acrName=`echo $1 | sed -e 's/^[^=]*=//g'`
      shift
      ;; 
    --printRegistrationFile)
      PRINT_REGISTRATION_FILE="cat registration.yaml"
      shift
      ;;   
    *)
      ;;
esac
done
  
sleepTime=5

#If --refreshFlexImage was set
if [[ "${REFRESH_IMAGE}" == "Y" ]]; then
  
  #log into ACR where image will be pulled from
  TOKEN=$(az acr login --name ${acrName} --expose-token --output tsv --query accessToken) > /dev/null
  docker login ${acrName}.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password $TOKEN > /dev/null

  #Attach the existing cluster to the existing ACR
  az aks update -n ${k8sCluster} -g ${k8sClusterRg} --attach-acr ${acrName} > /dev/null

  echo -e "\nImporting latest Flex GW Image into ACR..."
  #Pull latest image for flex-gateway and store it inside the ACR
  az acr import --name ${acrName} --source docker.io/mulesoft/flex-gateway:latest --image flex-gateway:latest
fi
kubectl create ns gateway > /dev/null
kubectl delete jobs/register-flex-gw -n gateway > /dev/null
kubectl apply -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k8sadmin
  namespace: gateway
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  namespace: gateway
  name: k8sadmin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: k8sadmin
    namespace: gateway
---    
apiVersion: batch/v1
kind: Job
metadata:
  name: register-flex-gw
  namespace: gateway
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 120
  template:
    spec:
      serviceAccountName: k8sadmin    
      containers:
      - name: flex-gateway-143
        image: FlexGWDockerHub.azurecr.io/flex-gateway
        command: ["/bin/sh"]
        args:
        - -c
        - >-
            echo "Installing Kubectl..." &&
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" > /dev/null &&
            install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl > /dev/null &&
            echo "Installing Helm..." &&
            curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 > /dev/null &&
            chmod 700 get_helm.sh > /dev/null &&
            ./get_helm.sh > /dev/null &&
            echo "Registering Flex GW..." &&
            flexctl register ${flexGatewayName} --token=${flexGatewayToken} --organization=${flexGatewayOrg} --output-directory=/tmp --connected=true &&
            eval ${PRINT_REGISTRATION_FILE} &&
            sleep ${sleepTime} &&
            echo "Installing Flex GW..." &&
            helm repo add flex-gateway https://flex-packages.anypoint.mulesoft.com/helm > /dev/null &&
            helm repo up > /dev/null &&
            helm -n gateway upgrade -i --create-namespace --wait ingress flex-gateway/flex-gateway --set-file registration.content=registration.yaml
        securityContext:
           allowPrivilegeEscalation: false
           runAsUser: 0
      restartPolicy: Never
EOF