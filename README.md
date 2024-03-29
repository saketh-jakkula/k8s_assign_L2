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
This script delivers 4 GCP instances, installs K8s cluster, installs helm, installs Guest book application and configures firewall rules, installs Prometheus and Grafana for monitoring and Dashboarding, installs EFK stack for centralized logging and installs required packages in Jenkins server.  

For simplicity it configured the master node to have static ip, which will be used to access the applications over the NodePort.  
Example:  
http://34.70.54.239:30080/ - Guestbook Application.  
http://34.70.54.239:30081/ - Prometheus.  
http://34.70.54.239:30082/ - Grafana.  
http://34.70.54.239:30084/ - Kibana.  

Here 34.70.54.239 is the static IP reserved for my implementation.
This cluster has 1 master and 2 nodes, script is capable to add the nodes to cluster with out manual intervention.

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
![alt text](https://github.com/saketh-linux/Pics/raw/master/sd.PNG)   
A new configuration can be added to prometheus-config-map.yml, a watch container is configured which can restart pods when a config changes.  
More details of the application health can be viewed through Grafana.

### Working with Grafana
Manifest files for this implemention can be found at monitoring/grafana.
In this example prometheus can be accessed through http://34.70.54.239:30082/.
1. Access the Grafana site admin/admin are the user/password, add the new datastore prometheus pointing to prometheus link.   
2. Import new dashboards 315 for cluster monitoring, it shows cpu, memory and File system usage for cluster, nodes, pods and containers.   
3. Import 3146 it is capable to show metrics of all the pods namespace wise. Select the namespace development to get the metrics of Guestbook application pods.  
4. For Application health check(Black box exporter) create a custom dashboard.
![alt text](https://github.com/saketh-linux/Pics/raw/master/grafana.PNG)   
The above example of singlestat panel and Graph shows if the application is up/down and time of status change.  
 a) Navigate to Add Row-> Add panel -> single stat      
 b) Under Metrics add a new prometheus query "probe_success{instance="http://34.70.54.239:30080",job="blackbox"}"    
 c) In the options change the threshold to 0,1 and the Gauge min-0 and max-1.  
 d) In value Mappings enter required ranges to show UP(0.5 - 1) or DOWN(0 - 0.5).
    

### Working with EFK
Manifest files for this implemention can be found at Logging/.
In this example prometheus can be accessed through http://34.70.54.239:30084/.   
Navigate Discover-> under create index pattern enter "logstash-*" it will capture all log data in Elastic search cluster.

## Details of cluster  
This example creates a 3 node cluster wich 1 master and 2 nodes.  
Installs Docker-18.09 and v1.15.1 of Kuberntes.  
For dynamic provision to work gave full access to cloud apis, added cloud provider config to kubeadm and kubelet. These changes are done automatically by wrapper.sh script.  
Enabled Oslogin option for GCP.   
