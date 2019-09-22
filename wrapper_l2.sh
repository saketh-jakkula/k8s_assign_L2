#!/bin/bash
##This wrapper script deleivers 3 gcp instances, Installs and sets up K8s, Installs Helm , Installs Guestbook Application, Installs Prometheus and Grafana for monitoring and EFK for centralized Loggging.

create_repo ()
{
cat <<- EOF 
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
         https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
}

install_k8s ()
{
cat <<- EOF
setenforce 0

sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

modprobe br_netfilter

echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
yum clean all
yum repolist
yum install -y yum-utils device-mapper-persistent-data lvm2 
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-18.09.*

sed -i '/^ExecStart/ s/$/ --exec-opt native.cgroupdriver=systemd/' /usr/lib/systemd/system/docker.service 
systemctl daemon-reload
systemctl enable docker --now
systemctl restart docker

cp /var/tmp/kubernetes.repo /etc/yum.repos.d/kubernetes.repo

yum install -y kubelet-1.15.1 kubeadm-1.15.1 kubectl-1.15.1
systemctl enable kubelet
echo 1 > /proc/sys/net/ipv4/ip_forward
EOF
}

create_kubeadm ()
{
cat <<- 'EOF'
yum install wget -y
wget https://raw.githubusercontent.com/saketh-linux/logging/master/gce.yml 
kubeadm init --config=gce.yml
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

EOF
}

add_cloudprov ()
{
cat <<- EOF
sed -i.bak '/--kubeconfig=/c Environment=\"KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --cloud-provider=gce\"' /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

cat <<- EF > /etc/kubernetes/cloud-config
[Global]
project-id = "$project"
EF

systemctl daemon-reload
systemctl restart kubelet.service

EOF
}

install_app ()
{
cat <<- 'EOF'

echo "creating jenkins SA"
kubectl create sa jenkins
kubectl create clusterrolebinding jenkins-cluster-rule --clusterrole=cluster-admin --serviceaccount=default:jenkins

echo "setting development ns"
kubectl create ns development
kubectl config set-context development --namespace=development --cluster=kubernetes --user=kubernetes-admin
kubectl config use-context "development"

echo "Installing Helm"
curl https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz > ./helm.tar.gz

tar -xvf ./helm.tar.gz
cd linux-amd64
mv ./helm /usr/local/bin
/usr/local/bin/helm init
/usr/local/bin/helm init --upgrade
sleep 5
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p'{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
/usr/local/bin/helm repo add helm_charts https://raw.githubusercontent.com/saketh-linux/helm_charts/master/
/usr/local/bin/helm repo update
#sleep 5
#echo "Installing Guest book app"
#/usr/local/bin/helm install helm_charts/guestbook
#if [ `echo $?` -eq 1 ]; then
#  echo "Installing app failed"
#  exit 1
#fi

echo "Install Prometheus/Grafana"
cd ~
yum  install git -y
git clone https://github.com/saketh-linux/monitoring.git
cd monitoring/prometheus
kubectl apply -f namespaces.yml
kubectl apply -f clusterRole.yml
kubectl apply -f kube-state-metrics.yml
kubectl apply -f prometheus-config-map.yml
kubectl apply -f prometheus-deployment.yml
kubectl apply -f prometheus-service.yml
kubectl apply -f blackbox_k8s.yml

cd ../grafana
kubectl apply -f grafana-sc.yml
kubectl apply -f grafana-deployment.yml
kubectl apply -f grafana-service.yml

kubectl get svc -n monitoring

echo "Install EFK"
cd ~
git clone https://github.com/saketh-linux/logging.git
cd logging
kubectl apply -f kube-logging.yaml
kubectl apply -f storage_sc.yml
kubectl apply -f elasticsearch_svc.yaml
kubectl apply -f elasticsearch_statefulset.yaml
kubectl apply -f kibana.yaml
kubectl apply -f fluentd.yml

EOF
}

jenkins_install ()
{
cat <<- EOF
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
yum install jenkins  java-1.8.0-openjdk-devel git -y
systemctl enable jenkins && systemctl restart jenkins
EOF
}


rm -f /home/cloud_user/.ssh/known_hosts
echo $1
if [ "$2" = '' ]; then
  echo "Please enter project id and zone"
  exit 1
fi

alias gssh='gcloud compute ssh --project "$project" --zone "$zone"'

project=$1
zone=$2

gcloud compute addresses create k8smaster  --region $zone
address=`gcloud compute addresses list|awk '{print $2}'|grep -v [a-z/A-Z]`

gcloud beta compute --project=$project instances create instance-1 --zone=$zone --machine-type=n2-standard-2 --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=298530575220-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append,https://www.googleapis.com/auth/cloud-platform --image=centos-7-v20190905 --image-project=centos-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=instance-1 --reservation-affinity=any --address=$address

for i in  2 3; do
  gcloud beta compute --project=$project instances create instance-$i --zone=$zone --machine-type=n2-standard-2 --subnet=default --network-tier=PREMIUM --maintenance-policy=MIGRATE --service-account=298530575220-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append,https://www.googleapis.com/auth/cloud-platform --image=centos-7-v20190905 --image-project=centos-cloud --boot-disk-size=10GB --boot-disk-type=pd-standard --boot-disk-device-name=instance-1 --reservation-affinity=any
done

gcloud compute instances add-tags instance-4 --tags jenkins-net
gcloud compute firewall-rules create k8s-traffic --allow tcp:30080,tcp:30081,tcp:30082,tcp:30083,tcp:30084 --source-ranges=0.0.0.0/0
gcloud compute firewall-rules create jenkins-traffic --allow tcp:8080 --target-tags jenkins-net --source-ranges=0.0.0.0/0

sleep 5

#j=0
#val=`gcloud compute instances list|awk '{print $5}'|grep '[0-9]'`
#for i in $val;do
#  j=$(expr $j + 1)
#  cat /etc/hosts|grep "instance-$j"
#  if [ `echo $?` -eq 0 ]; then
#     sudo sed -i.bak "/instance-$j/d" /etc/hosts
#  fi
#  echo $i "instance-$j" | sudo tee -a /etc/hosts
#done

install_k8s > script.sh
create_repo >  kubernetes.repo
create_kubeadm > kubeadm.sh

for i in 1 2 3; do
  gcloud beta compute scp script.sh kubernetes.repo instance-$i:/var/tmp --project $project --zone $zone
  gssh instance-$i  -- 'sudo sh /var/tmp/script.sh'
done

gcloud beta compute scp kubeadm.sh instance-1:/var/tmp --project $project --zone $zone
gssh instance-1  -- 'sudo sh /var/tmp/kubeadm.sh' > out

var=`cat out |egrep 'kubeadm join|discovery'|tr -d '\n' |tr -d '\'|tr -d '\r'`

for i in 2 3; do
  gssh instance-$i -- "sudo $var"
done

gssh instance-1 -- "sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml; curl -k https://localhost:6443/healthz"

add_cloudprov > cloud_prov.sh

for i in 1 2 3; do
  gcloud beta compute scp cloud_prov.sh  instance-$i:/var/tmp --project $project --zone $zone
  gssh instance-$i -- 'sudo sh /var/tmp/cloud_prov.sh'
done

install_app > app.sh

gcloud beta compute scp app.sh instance-1:/var/tmp --project $project --zone $zone
gssh instance-1 -- "sudo sh /var/tmp/app.sh"
gssh instance-1 -- 'sudo /usr/local/bin/helm install helm_charts/guestbook'

jenkins_install > jenkins.sh

gcloud beta compute scp jenkins.sh  instance-4:/var/tmp --project $project --zone $zone
gssh instance-4 -- 'sudo sh /var/tmp/jenkins.sh'

rm -f jenkins.sh cloud_prov.sh app.sh script.sh kubernetes.repo script.sh
