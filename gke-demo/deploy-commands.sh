##########################
# GKE CLUSTER CREATE
##########################
# --- Enable the Google Kubernetes Engine API
# --- Ensure that you have enabled the IAM Service Account Credentials API
# --- https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
gcloud container clusters create demo --zone us-central1-a --machine-type e2-medium --num-nodes 2
gcloud container clusters get-credentials demo --zone us-central1-a
gcloud container clusters list
alias k=kubectl
alias c=clear
k get all -A

##########################
# IMAGE BUILD
##########################
mkdir demo
cd demo/
vi Dockerfile
# --- Create repository and enable the Artifact Registry API
# --- https://cloud.google.com/artifact-registry/docs/docker/store-docker-container-images
gcloud artifacts repositories list
gcloud auth configure-docker     us-central1-docker.pkg.dev
docker images
docker rmi f3deb3f2fd69
docker build .
docker images
docker tag f3deb3f2fd69 us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v1.0.0
docker images
docker push us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v1.0.0

##########################
# WORK ENV BOOTSTRAP
##########################
sudo apt install zsh
wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
rm -rf install.sh
git clone https://github.com/jonmosco/kube-ps1.git
vi ~/.zshrc
      source ~/demo/kube-ps1/kube-ps1.sh
      PROMPT='$(kube_ps1)'$PROMPT
      alias k=kubectl
source ~/.zshrc
source <(kubectl completion zsh)
kubectl completion zsh > "${fpath[1]}/_kubectl"


##########################
# K8S DEPLOYMENT
##########################
k create ns demo
k get ns
k config set-context --current --namespace demo
docker images
k create deployment demo --image us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v1.0.0
k get deploy
k expose deployment demo --port 80 --type LoadBalancer --target-port 8080
k get svc -w
curl 34.170.230.60
# --- check availability from other terminal
LB=$(k get svc demo -o jsonpath="{..ingress[0].ip}")
alias k=kubectl
LB=$(k get svc demo -o jsonpath="{..ingress[0].ip}")
curl $LB
while true; do curl $LB; sleep 0.3; done
# --- set Version: v2.0.0 into Dockerfile
vi Dockerfile
docker build . -t us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v2.0.0
docker push us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v2.0.0
k set image deploy demo demo=us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v2.0.0
k get deployment.apps -o wide
# --- rollout usage
k rollout history deploy demo
k rollout undo deploy demo --to-revision 1
k get deployment.apps -o wide
k set image deploy demo demo=us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v2.0.0 --record 
k rollout history deploy demo
k annotate deploy demo kubernetes.io/change-cause="update to v2.0.0"
k get deployment.apps -o wide
# --- create dedicated deployment for v2.0.0
k create deployment demo-2 --image=us-central1-docker.pkg.dev/engaged-card-466414-h6/demo/demo:v2.0.0
k get deploy
# --- labeling
k get po -o wide --show-labels
k label po --all run=demo
k get po -o wide --show-labels
k label po demo-7b6f64cf49-pfvpb run=demo
# --- change Selector "app: demo" -> "run: demo"
k edit svc demo
k get svc -o wide
k get po --show-labels
k get po -l run=demo
# --- deployment scaling
k scale deploy demo --replicas 9
k scale deploy demo --replicas 1 && k label pod --all run=demo

##########################
# RESOURCE CLEAN UP
##########################
gcloud container clusters delete demo --location us-central1-a