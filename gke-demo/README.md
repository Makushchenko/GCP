# GKE + Artifact Registry + Canary (25%) → Blue‑Green (100%)

This guide shows how to:

1. **Create a GKE cluster** and connect `kubectl`.
2. **Build & push** container images to **Artifact Registry**.
3. **Deploy v1.0.0**, then roll out **v2.0.0** using:

   * **Canary** at \~25% traffic (by replica ratio), then
   * **Blue‑Green** cutover to 100%.
4. **Monitor** the service from **UptimeRobot**.
5. **Clean up** resources safely.

> All commands are based on your history and are meant to be copy‑paste ready. Replace `<PROJECT_ID>`, regions, and names as needed.

---

## Prerequisites

* gcloud SDK installed & authenticated
* A GCP project selected: `gcloud config set project <PROJECT_ID>`
* Enable required APIs:

```bash
# Kubernetes Engine, Artifact Registry, and IAM SA Credentials
gcloud services enable container.googleapis.com \
  artifactregistry.googleapis.com \
  iamcredentials.googleapis.com
```

> (Optional) For production-grade identity on GKE, see Workload Identity docs.

---

## 1) Create a GKE Cluster

```bash
gcloud container clusters create demo \
  --zone us-central1-a \
  --machine-type e2-medium \
  --num-nodes 2

# Fetch kubeconfig
gcloud container clusters get-credentials demo --zone us-central1-a

# Quick sanity
kubectl get all -A
```

Convenience aliases (optional):

```bash
alias k=kubectl
alias c=clear
```

---

## 2) Build & Push Image to Artifact Registry

1. **Create (or verify) a Docker repository** (regional example):

```bash
gcloud artifacts repositories create demo \
  --repository-format=docker \
  --location=us-central1 \
  --description="Demo Docker repo" 2>/dev/null || true

gcloud artifacts repositories list
```

2. **Authenticate Docker** to Artifact Registry:

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

3. **Build, tag, and push** `v1.0.0`:

```bash
# in your app folder
mkdir -p demo && cd demo
# (edit your Dockerfile as needed)

# Build
docker build -t demo:build .

# Tag to Artifact Registry
docker tag demo:build \
  us-central1-docker.pkg.dev/<PROJECT_ID>/demo/demo:v1.0.0

# Push
docker push us-central1-docker.pkg.dev/<PROJECT_ID>/demo/demo:v1.0.0
```

---

## 3) Bootstrap Shell (optional quality-of-life)

```bash
sudo apt-get update && sudo apt-get install -y zsh
wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
# (run installer as needed, then)
# Example kube-ps1
git clone https://github.com/jonmosco/kube-ps1.git ~/kube-ps1
cat >> ~/.zshrc <<'EOF'
source ~/kube-ps1/kube-ps1.sh
PROMPT='$(kube_ps1) '$PROMPT
alias k=kubectl
EOF
source ~/.zshrc
# kubectl completion for zsh
source <(kubectl completion zsh)
kubectl completion zsh > "${fpath[1]}/_kubectl"
```

---

## 4) Deploy v1.0.0 to GKE

```bash
k create ns demo
k config set-context --current --namespace demo

# Deploy v1
k create deployment demo \
  --image=us-central1-docker.pkg.dev/<PROJECT_ID>/demo/demo:v1.0.0

# Expose via external LoadBalancer
k expose deployment demo \
  --port 80 --type LoadBalancer --target-port 8080

# Wait for an external IP
k get svc -w
```

Grab the LB IP and test:

```bash
LB=$(k get svc demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "$LB"
curl -sS http://$LB
# optional: live test loop
# while true; do curl -sS http://$LB; sleep 0.3; done
```

---

## 5) Build & Push v2.0.0

```bash
# Update your Dockerfile/app to Version: v2.0.0
# Then build & push

docker build -t demo:v2 .
docker tag demo:v2 \
  us-central1-docker.pkg.dev/<PROJECT_ID>/demo/demo:v2.0.0
docker push us-central1-docker.pkg.dev/<PROJECT_ID>/demo/demo:v2.0.0
```

---

## 6) Rollout Strategies

> **Labeling pattern**: keep `app=demo` on both versions, add `version=v1` or `version=v2` so we can control Service selection for blue‑green. For replica‑weighted canary we’ll let both versions match the Service selector.

### 6.1 Canary \~25%

**Goal:** send \~25% of traffic to v2 while 75% stays on v1.

We’ll run **two Deployments** with the same `app=demo` label so the Service sends traffic to both. Traffic split is **approximate** and based on **pod counts**.

```bash
# Ensure v1 has labels
k patch deploy demo -p '{
  "spec": {"template": {"metadata": {"labels": {"app":"demo","version":"v1"}}}}
}'

# Create v2 deployment (1 replica initially)
k create deployment demo-v2 \
  --image=us-central1-docker.pkg.dev/<PROJECT_ID>/demo/demo:v2.0.0

# Add labels to v2 pods
k patch deploy demo-v2 -p '{
  "spec": {"template": {"metadata": {"labels": {"app":"demo","version":"v2"}}}}
}'

# Scale v1 to 3 replicas (~75%) and v2 to 1 replica (~25%)
k scale deploy demo --replicas 3
k scale deploy demo-v2 --replicas 1

# Service currently selects app=demo (both versions)
k get svc demo -o yaml | sed -n '/selector:/,/type:/p'
```

**Observe** responses at the LB URL to see mixed versions. If your app returns a version string, you’ll see \~1 in 4 requests show `v2.0.0`.

**Roll forward** (increase v2 replicas) or **roll back** (scale v2 to 0) as needed:

```bash
# Roll forward example: 50/50
k scale deploy demo-v2 --replicas 2

# Roll back to 0% v2 (stop canary)
k scale deploy demo-v2 --replicas 0
```

### 6.2 Blue‑Green 100%

**Goal:** shift **all** traffic to v2 instantly with the ability to revert.

Approach: switch the Service selector from `app=demo` to `app=demo,version=v2`.

```bash
# Ensure v2 is healthy and scaled (e.g., 3 replicas)
k scale deploy demo-v2 --replicas 3

# Update Service selector to target only v2
k patch svc demo --type merge -p '{
  "spec": {"selector": {"app":"demo","version":"v2"}}
}'

# Verify endpoints now point only to v2
k get endpointslice -l kubernetes.io/service-name=demo -o wide
```

**Rollback (to v1):**

```bash
k patch svc demo --type merge -p '{
  "spec": {"selector": {"app":"demo","version":"v1"}}
}'
```

> You can keep the v1 Deployment running (green/blue) for quick rollback, then delete it when confident.

**Useful rollout commands:**

```bash
k rollout history deploy demo
k rollout history deploy demo-v2
k rollout undo deploy demo --to-revision=1
```

---

## 7) Monitor with UptimeRobot (v1 Canary → v2 Blue‑Green)

**Objective:** Track uptime during canary and during the final blue‑green cutover using **two explicit monitors** and showcase them on a **public Status Page**.

### Monitors to create

* **`gke-deploy-demo-v1.0.0`** — create **after** the `demo` Deployment is **Ready** and the `demo` Service has an external **LB IP** (v1 live and serving).
* **`gke-deploy-demo-2-v2.0.0`** — create **after** `demo-v2` is deployed and healthy and you have **completed Canary and Blue‑Green** (Service now routes 100% to v2).

> Example public Status Page (add both monitors to it): **[https://stats.uptimerobot.com/VN0VU24eTA](https://stats.uptimerobot.com/VN0VU24eTA)**

### How to add the v1 monitor

1. Go to **[https://uptimerobot.com/](https://uptimerobot.com/)** → sign in.
2. **+ New Monitor** → **Monitor Type:** `HTTP(s)`.
3. **Friendly Name:** `gke-deploy-demo-v1.0.0`.
4. **URL:** `http://<LB_IP>` (or `http://<LB_IP>/version` if your app exposes a version endpoint).
5. **Monitoring Interval:** e.g., `1 minute`.
6. **Alert Contacts:** pick email/Telegram/etc.
7. **Create Monitor**.

### Canary observation (25%)

* Keep the **v1 monitor** active during canary.
* (Optional, if `/version` exists) create a **Keyword** check looking for `v1.0.0` to validate most responses are v1 while canary is \~25% v2.

### After Blue‑Green cutover → add v2 monitor

1. Once the Service selector targets only **v2** and pods are healthy, create **another** `HTTP(s)` monitor:

   * **Friendly Name:** `gke-deploy-demo-2-v2.0.0`
   * **URL:** `http://<LB_IP>` (or `/version` endpoint)
   * (Optional) **Keyword** check: `v2.0.0` to confirm 100% v2
2. Keep **both monitors** so you can compare historical uptime of v1 vs v2.

### Add both monitors to a public Status Page

1. In UptimeRobot, go to **Status Pages** → **+ Create**.
2. **Select monitors:** add `gke-deploy-demo-v1.0.0` and `gke-deploy-demo-2-v2.0.0`.
3. Publish and share the URL (e.g., **[https://stats.uptimerobot.com/VN0VU24eTA](https://stats.uptimerobot.com/VN0VU24eTA)**).

**Notes**

* Ensure the Kubernetes Service is **type LoadBalancer** and firewall rules allow HTTP.
* Prefer monitoring a **DNS name** mapped to the LB IP for stability (A/AAAA record), but raw IP works too.

---

## 8) Cleanup

```bash
gcloud container clusters delete demo --zone us-central1-a
```

If you created disks, Artifact Registry images, or static IPs during experiments, delete them to avoid charges.

---

## Appendix: Handy one‑liners

```bash
# Watch service for LB IP changes
k get svc demo -w

# Grab LB IP into a shell var
LB=$(k get svc demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Quick continuous probe
# while true; do curl -sS http://$LB; sleep 0.3; done
```

---

### Troubleshooting Tips

* `gcloud container clusters delete` requires a **zone or region** when not set in defaults.
* If `docker push` to Artifact Registry fails, re‑run: `gcloud auth configure-docker us-central1-docker.pkg.dev`.
* Canary split via pod counts is **best‑effort**; it’s not exact weighted routing. For precise weights, use a service mesh (e.g., Istio) or cloud L7 LB traffic splitting.