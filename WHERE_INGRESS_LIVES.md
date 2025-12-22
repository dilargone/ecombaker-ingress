# Where Does Ingress Live? 🏠

## The Short Answer

**Ingress runs INSIDE your Kubernetes cluster as a pod/deployment, just like your backend and frontend services.**

## Visual Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INTERNET                                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ DNS: *.dev.ecombaker.com → 1.2.3.4
                             │
                             ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    CLOUD LOAD BALANCER                               │
│              (AWS ELB / GCP LB / Azure LB)                          │
│              External IP: 1.2.3.4                                    │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ Port 80/443
                             │
┌─────────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                                │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │   NGINX INGRESS CONTROLLER (Running as Pod)                  │   │
│  │   Namespace: ingress-nginx                                   │   │
│  │   Type: DaemonSet or Deployment                              │   │
│  │   ┌─────────────────────────────────────────────────────┐   │   │
│  │   │  Pod: ingress-nginx-controller-xxxxx                │   │   │
│  │   │  - Reads your ingress-patch.yaml rules              │   │   │
│  │   │  - Routes traffic based on host + path              │   │   │
│  │   │  - Handles SSL/TLS termination                      │   │   │
│  │   │  - Enforces rate limiting, CORS, etc.              │   │   │
│  │   └─────────────────────────────────────────────────────┘   │   │
│  └────────────────────────┬────────────────────────────────────┘   │
│                            │                                         │
│         ┌──────────────────┴──────────────────┐                    │
│         │ Reads Ingress Resources             │                    │
│         ↓                                      ↓                    │
│  ┌──────────────────┐              ┌──────────────────┐           │
│  │ Ingress Resource │              │ Ingress Resource │           │
│  │ (Your Config)    │              │ (Other Apps)     │           │
│  │ ecombaker-ingress│              │ other-ingress    │           │
│  └──────────────────┘              └──────────────────┘           │
│                                                                     │
│         Routes traffic to:                                         │
│         ┌──────────────────┴──────────────────┐                   │
│         ↓                                      ↓                   │
│  ┌─────────────────────┐            ┌─────────────────────┐      │
│  │ Backend Service     │            │ Frontend Service    │      │
│  │ pilot-service-dev   │            │ pilot-frontend-dev  │      │
│  │ (Port 8080)         │            │ (Port 80)           │      │
│  │                     │            │                     │      │
│  │  ┌───────────────┐  │            │  ┌───────────────┐  │      │
│  │  │ Pod: backend  │  │            │  │ Pod: frontend │  │      │
│  │  │ (Spring Boot) │  │            │  │ (React/Vue)   │  │      │
│  │  └───────────────┘  │            │  └───────────────┘  │      │
│  └─────────────────────┘            └─────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## The Two Parts of "Ingress"

### 1. **NGINX Ingress Controller** (The Software)
- **What it is**: A pod running NGINX that acts as a reverse proxy/load balancer
- **Where it runs**: Inside your Kubernetes cluster (namespace: `ingress-nginx`)
- **How it gets installed**: 
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
  ```
- **What it does**: 
  - Listens on port 80 (HTTP) and 443 (HTTPS)
  - Reads ALL Ingress resources in the cluster
  - Dynamically updates NGINX config
  - Routes traffic to correct services

### 2. **Ingress Resource** (Your Configuration)
- **What it is**: The YAML file you're looking at (`ingress-patch.yaml`)
- **Where it lives**: 
  - **Code**: In your Git repo (`ecombaker-ingress-repo`)
  - **Runtime**: Stored in Kubernetes as a resource (like a ConfigMap)
- **What it does**: Tells the NGINX controller HOW to route traffic

## Step-by-Step: Where Everything Lives

### Step 1: Install NGINX Ingress Controller
```bash
# This creates pods in your cluster
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Verify it's running
kubectl get pods -n ingress-nginx
# NAME                                      READY   STATUS    RESTARTS   AGE
# ingress-nginx-controller-xxxxxxxxxx       1/1     Running   0          5m
```

**Result**: You now have an NGINX pod running in namespace `ingress-nginx`

### Step 2: Deploy Your Ingress Configuration
```bash
cd ecombaker-ingress-repo
./scripts/deploy.sh dev

# Or with kubectl
kubectl apply -k overlays/dev
```

**What happens**:
1. Kubernetes stores your ingress rules as a resource
2. NGINX Ingress Controller detects the new Ingress resource
3. NGINX updates its internal routing table
4. Traffic now routes according to your rules

### Step 3: Check Where It's Running
```bash
# See the ingress controller pod
kubectl get pods -n ingress-nginx
# ingress-nginx-controller-7d6f8bf7c5-abcde   1/1   Running

# See your ingress resource
kubectl get ingress -n default
# NAME                 CLASS   HOSTS                   ADDRESS      PORTS
# ecombaker-ingress    nginx   *.dev.ecombaker.com     1.2.3.4      80, 443

# See the external IP (where traffic enters)
kubectl get svc -n ingress-nginx ingress-nginx-controller
# NAME                       TYPE           CLUSTER-IP      EXTERNAL-IP
# ingress-nginx-controller   LoadBalancer   10.96.123.45    1.2.3.4
```

## Physical Location

### In the Cloud (Most Common)

**Example: AWS EKS**
```
AWS Account
└── Region: us-east-1
    └── EKS Cluster: my-cluster
        ├── Node: ec2-instance-1 (t3.medium)
        │   ├── Pod: ingress-nginx-controller-xxxxx  ← INGRESS RUNS HERE
        │   └── Pod: backend-pod-xxxxx
        ├── Node: ec2-instance-2 (t3.medium)
        │   └── Pod: frontend-pod-xxxxx
        └── Load Balancer: ELB-abc123  ← PUBLIC IP (1.2.3.4)
            └── Forwards traffic to ingress pods
```

**Example: GCP GKE**
```
GCP Project
└── Region: us-central1
    └── GKE Cluster: my-cluster
        ├── Node Pool: default-pool
        │   ├── Node: gke-node-1
        │   │   ├── Pod: ingress-nginx-controller  ← INGRESS RUNS HERE
        │   │   └── Pod: backend-pod
        │   └── Node: gke-node-2
        │       └── Pod: frontend-pod
        └── Load Balancer: GCP LB  ← PUBLIC IP (1.2.3.4)
```

### On-Premises
```
Your Data Center
└── Kubernetes Cluster (bare metal)
    ├── Server 1: 192.168.1.10
    │   └── Pod: ingress-nginx-controller  ← INGRESS RUNS HERE
    ├── Server 2: 192.168.1.11
    │   └── Pod: backend-pod
    └── Server 3: 192.168.1.12
        └── Pod: frontend-pod
```

## How Traffic Flows (Complete Path)

### Request: `https://store1.dev.ecombaker.com/api/products`

```
1. USER'S BROWSER
   └─→ DNS lookup: *.dev.ecombaker.com
       └─→ Returns: 1.2.3.4 (Load Balancer IP)

2. CLOUD LOAD BALANCER (1.2.3.4)
   └─→ Receives: HTTPS request on port 443
       └─→ Forwards to: NGINX Ingress Controller pod

3. NGINX INGRESS CONTROLLER POD (Inside cluster)
   Location: Kubernetes worker node
   Namespace: ingress-nginx
   └─→ Reads: Host header (store1.dev.ecombaker.com)
   └─→ Reads: Path (/api/products)
   └─→ Matches: Your ingress rule (path: /api → pilot-service-dev:8080)
   └─→ Forwards to: Kubernetes service "pilot-service-dev"

4. KUBERNETES SERVICE (pilot-service-dev)
   └─→ Load balances to one of the backend pods
       └─→ Selects: backend-pod-xxxxx (based on label selector)

5. BACKEND POD (Your Spring Boot app)
   Location: Some worker node in the cluster
   └─→ Handles: GET /api/products
       └─→ Returns: JSON response

6. RESPONSE FLOWS BACK
   Backend pod → Service → Ingress → Load Balancer → User
```

## Key Insights

### 1. Ingress Controller is NOT Special
It's just another pod in your cluster, like your backend or frontend:

```bash
# All these are pods running in your cluster:
kubectl get pods --all-namespaces
# NAMESPACE       NAME                                    READY
# ingress-nginx   ingress-nginx-controller-xxxxx          1/1    ← Ingress
# default         pilot-service-dev-xxxxx                 1/1    ← Your backend
# default         pilot-frontend-service-dev-xxxxx        1/1    ← Your frontend
```

### 2. Your Config is Just Data
Your `ingress-patch.yaml` is stored as a Kubernetes object:

```bash
kubectl get ingress ecombaker-ingress -o yaml
# Shows your configuration stored in the cluster
```

### 3. One Controller, Many Ingresses
One NGINX Ingress Controller can handle ingress rules from multiple apps:

```bash
kubectl get ingress --all-namespaces
# NAMESPACE   NAME                HOSTS
# default     ecombaker-ingress   *.dev.ecombaker.com
# app1        app1-ingress        app1.example.com
# app2        app2-ingress        app2.example.com
```

## Where Your Ingress Repo Files Live

```
┌────────────────────────────────────────────────────────────┐
│  YOUR LAPTOP / CI/CD                                        │
│  /Users/dila.gurung.1987/.../ecombaker-ingress-repo/       │
│  ├── overlays/dev/ingress-patch.yaml  ← SOURCE CODE        │
│  └── scripts/deploy.sh                                      │
└──────────────────────┬─────────────────────────────────────┘
                       │
                       │ kubectl apply -k overlays/dev
                       ↓
┌────────────────────────────────────────────────────────────┐
│  KUBERNETES CLUSTER (etcd database)                         │
│  ├── Ingress Object: ecombaker-ingress  ← STORED AS DATA   │
│  │   (contains your rules)                                  │
│  └── ConfigMaps, Secrets, etc.                             │
└──────────────────────┬─────────────────────────────────────┘
                       │
                       │ Reads continuously
                       ↓
┌────────────────────────────────────────────────────────────┐
│  NGINX INGRESS CONTROLLER POD                              │
│  Namespace: ingress-nginx                                   │
│  ├── Watches for Ingress resources                         │
│  ├── Generates NGINX config                                │
│  └── Routes traffic  ← RUNTIME, RUNNING SOFTWARE           │
└────────────────────────────────────────────────────────────┘
```

## Summary

**Where does ingress "sit"?**

1. **The Controller (NGINX)**: Runs as a pod inside your Kubernetes cluster (namespace: `ingress-nginx`)
2. **Your Configuration**: Stored in Kubernetes etcd database, read by the controller
3. **Your Repo**: Source code on GitHub, deployed via kubectl/GitHub Actions
4. **The Entry Point**: Cloud Load Balancer with public IP (1.2.3.4)

**Physical location**: On worker nodes in your Kubernetes cluster, wherever Kubernetes schedules the ingress controller pod.

**Think of it like this**:
- **Your backend code** = Running in a pod on Node 1
- **Your frontend code** = Running in a pod on Node 2  
- **Ingress controller** = Running in a pod on Node 3 ← **Same level as your apps!**
- **Your ingress rules** = Configuration data, like a ConfigMap

It's NOT a separate server or external service—it's part of your Kubernetes cluster! 🎯
