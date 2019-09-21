pipeline {
    agent any
    stages {
        stage('Install Kubectl') {
            when {
                expression { sh(returnStatus: true, script: 'ls -l /usr/bin/kubectl 1>/dev/null 2>/dev/null') != 0 }
            }
            steps {
                sh label: '', script: '''cat << EOF |  sudo tee -a /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

sudo yum install kubectl -y
'''
            }
        }
      stage('Install Helm') {
            when {
                expression { sh(returnStatus: true, script: 'ls -l /usr/bin/helm 1>/dev/null 2>/dev/null') != 0 }
            }
            steps{
                sh label: '', script: '''curl https://storage.googleapis.com/kubernetes-helm/helm-v2.12.3-linux-amd64.tar.gz > ./helm.tar.gz
tar -xvf ./helm.tar.gz
sudo mv linux-amd64/helm /usr/bin'''
            }
        }

    }
}
node {
  stage('List pods') {
    withKubeConfig([credentialsId: '<secret ID>',
                    caCertificate: '''<CA KEY>''',
                    serverUrl: '<server url>',
                    contextName: 'jenkins',
                    clusterName: 'kubernetes',
                    namespace: 'development'
                    ]) {
      sh 'kubectl get pods'
      sh 'helm init -c'
      sh 'helm repo add helm_charts https://raw.githubusercontent.com/saketh-linux/helm_charts/master/'
      sh 'helm repo update'
      sh 'helm install helm_charts/guestbook'
      
    }
  }
}
