# Flex Gateway Quickstart on AKS
This repository contains a quickstart script, intended for those who want to do a quick test of Flex Gateway running as an Ingress in Connected mode on an AKS cluster. It is NOT recommended for production-ready installations. Such installations should always be monitored and, while this script is a good base, it should be customized as needed.

## Why?
The installation of Flex Gateway, although simple, requires the execution of a series of Docker and Helm commands. A user with Azure CLI privileges cannot execute such commands directly, but requires prior environment preparation (e.g. helm instlalation on the nodes, privileged containers to run Docker commands). This script tries to help with that task.

## How does it works?
The script can be divided into two large parts:
1 - Preparation and parsing of flags: reading the input arguments and setting variables that will determine which commands are executed
2 - Execution of the necessary commands (Azure, OS & Kubernetes): updating the Flex Gateway image (optional) and creating the kubernetes objects needed for installation. Internally the script does the following on the k8s environment:
- Creates a ServiceAccount on the Gateway namespace called k8sAdmin with privileges over the cluster
- Creates a clustertrRoleBinding to assing the role cluster-admin to the created ServiceAccount (this is what gives privileges to the job that will perform the registration and the installation, explained next)
   - Creates a Job that will create a new pod called called register-flex-gw-* under Gateway namespace that will:
        * Install Kubectl
        * Install Helm
        * Execute flexctl register to register with Anypoint Control Plane
        * Execute helm gateway upgrade to install the ingress

NOTE: Please note that only one replica of the Flex Gateway will be installed. Additional replicas can be installed following the manual procedure documented on the MuleSoft's official documentation    

## Pre-requisites
Before using this script, your environment should consist of the following:
- An AKS cluster already created with at least 1 node
- An Azure Container Registry, which will be used to store the Flex Gateway image. To create an acr: https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration?tabs=azure-cli
- Have the proper entitlements to register Flex Gateway on Anypoint Platform
- The script was already copied to your home directory (or any other directory you have access to) on Azure CLI

## Usage Steps
1 - Log into Anypoint Platform, navigate to Runtime Manager, Flex Gateway tab, Add Gateway button
2 - Select Kubernetes option. Copy the organization and token values listed on step 2
3 - Go to Azure CLI
4 - Execute the script based on the available flags

## Available Command Flags 

`sh AKS-FlexGWInstall.sh [arguments] [options]`

    arguments:
    --flexName                specify the Flex Gateway Name to register
    --flexToken               specify the token to register the Flex Gateway (Obtained from AP Control Plane)
    --orgId                   specify the OrgID where to register and iinstall the Flex Gateway

    options:
    -h                        Print a help message to assist with usage
    --refreshFlexImage        When specified, the script will try to pull the latest image from Docker hub (this requires a predefined Azure Container Registry)
    --aksClusterName          Name of the existing AKS cluster where Flex will be installed. Use it only when --refreshFlexImage is set
    --aksClusterRgName        Name of the existing Resource Group where the AKS cluster was created. Use it only when --refreshFlexImage is set
    echo "--acrName                 Name of the existing Azure Container Registry (ACR). Use it only when --refreshFlexImage is set"  
    --printRegistrationFile   When specified, the container logs will print the registration.yaml file content. This is useful to register additional replicas without having to share persistent volumes between containers

# Contribution
Want to contribute? Great!

- For public contributions - Just fork the repo, make your updates and open a pull request!
- For internal contributions - Use a simplified feature workflow following these steps:
	- Clone your repo
	- Create a feature branch using the naming convention feature/name-of-the-feature (please include evidence and testing results)
	- Once it's ready, push your changes
	- Open a pull request for a review