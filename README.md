# k8s_assign_L2
Process to create custom k8s cluster on GCP instances and install Guest book appliaction.
## Prerequisites
Need to have a GCP account and create a project.  

Install gloud sdk on your local machine if you don't want to use google cloud shell. 
#### Steps to install gcloud sdk.  
1. sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM  
  [google-cloud-sdk]  
  name=Google Cloud SDK  
  baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64  
  enabled=1  
  gpgcheck=1  
  repo_gpgcheck=1  
  gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg  
         https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg  
  EOM  
2. Install the Cloud SDK  
  yum install google-cloud-sdk  
3. gcloud init --console-only 
4. Follow the steps to give gcloud sdk access to the GCP account and select the required project when prompted.  

Run **gcloud compute project-info add-metadata --metadata enable-oslogin=TRUE** to configure ssh over gcloud command and we don't need to worry about generating/exchanging ssh keys.  


## Installations

Clone this repository https://github.com/saketh-linux/k8s_assign_L2.git    

### Wrapper script
Run **sh wrapper_l2.sh <project_name> <zone_name>**     
This script delivers 4 GCP instances, installs K8s cluster, installs helm, installs Guest book application and configures firewall rules, installs Prometheus and Grafana for monitoring and Dashboarding, installs EFK stack for centralized logging.  

For simplicity it configured the master node to have static ip, which will be used to access the applications over the NodePort.  
Example:  
http://34.70.54.239:30080/ - Guestbook Application.  
http://34.70.54.239:30081/ - Prometheus.  
http://34.70.54.239:30082/ - Grafana.  
http://34.70.54.239:30084/ - Kibana.  

Here 34.70.54.239 is the static IP reserved for my implementation.

### Installing Guestbook through Jenkins.

When you run wrapper.sh script it configures the 4th instance as a Jenkins servers. Follow the below steps to start Jenkins and create a Pipeine.  
1. Run **gcloud compute instances list** and get the external ip address of the Jenkins server.  
2. Through wrapper.sh script a service account called jenkins has already been installed. Note Token and CA info by running the below commands.  
**kubectl get sa jenkins -o=jsonpath={.secrets[0].name} -- gives the secret name.  
kubectl get secret <secret> -o=jsonpath='{.data.token}' | base64 -d -- gives the token.  
kubectl get secret <secret> -o yaml|grep ca.crt|awk -d':' '{print $2}'| base64 -d -- gives the CA key.**  
3. Access the Jenkins URL with http://<Ipaddress>:8080 and create a new credentail, select secret text and enter the token.
4. Install a new plugin Kubernetes Cli Plugin to connect to kuberntes cluster.
5. Create a new pipeline and copy the content of the file install.groovy. You need to enter the secret id, server url and the CA KEY.

This script is capable to create environment needed for kubectl and helm. Once the application is installed kubectl configs are cleared.
  
### Working with Prometheus
Manifest files for this implemention can be found at monitoring/prometheus.
In this example prometheus can be accessed through http://34.70.54.239:30081/.   
Utilized kubernetes-sd-config to dynamically list the targets, this particular config can list apiserver, endpoints, cadvisor, nodes and pods.  
Implemented Blackbox exporter to monitor health of the application.  
A new configuration can be added to prometheus-config-map.yml, a watch container is configured which can restart pods when a config changes.
More details of the application can be viewed through Grafana.

### Working with Grafana

