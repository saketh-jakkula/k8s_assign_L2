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

## Installations

Clone this repository https://github.com/saketh-linux/k8s_assign_L2.git    

### Wrapper script
Run **sh wrapper_l2.sh <project_name> <zone_name>**     
This script delivers GCP instances, installs K8s cluster, installs helm, installs Guest book application and configures firewall rules, installs Prometheus and Grafana for monitoring and Dashboarding, installs EFK stack for centralized logging.  

For simplicity it configured the master node to have static ip, which will be used to access the applications over the NodePort.  
Example:  
http://34.70.54.239:30080/ - Guestbook Application.  
http://34.70.54.239:30081/ - Prometheus.  
http://34.70.54.239:30082/ - Grafana.  
http://34.70.54.239:30084/ - Kibana.  

Here 34.70.54.239 is the static IP reserved for my implementation.

### Installing Guestbook with Jenkins.

