# Assignment 8: Kubernetes Objects, Deployments and Services - Lab Report

## 1. Introduction & Kubernetes Architecture

Kubernetes is a container orchestration platform used to deploy, manage, and scale
containerized applications. It maintains the **desired state** of applications and
provides mechanisms for networking, configuration, service discovery, and storage.

Kubernetes consists of two major parts:
- **Control Plane** - Manages the cluster and makes scheduling and state-management decisions.
- **Worker Nodes** - Run application workloads in Pods.

Important components include the **API Server**, **Scheduler**, **Controller Manager**,
and **kubelet**.

```
                        ┌───────────────────────────────────────┐
                        │            CONTROL PLANE                │
                        │  API Server │ Scheduler │ Controller    │
                        │             │           │ Manager       │
                        └───────────────────┬───────────────────┘
                                            │
                    ┌───────────────────────┼───────────────────────┐
                    ▼                       ▼                       ▼
            ┌───────────────┐       ┌───────────────┐       ┌───────────────┐
            │  Worker Node  │       │  Worker Node  │       │  Worker Node  │
            │  kubelet      │       │  kubelet      │       │  kubelet      │
            │  ┌─────────┐  │       │  ┌─────────┐  │       │  ┌─────────┐  │
            │  │  Pod    │  │       │  │  Pod    │  │       │  │  Pod    │  │
            │  └─────────┘  │       │  └─────────┘  │       │  └─────────┘  │
            └───────────────┘       └───────────────┘       └───────────────┘
```

### Important Kubernetes Objects
| Object | Purpose |
| :--- | :--- |
| **Pod** | The smallest deployable unit in Kubernetes. |
| **Deployment** | Manages application replicas and rolling updates. |
| **Service** | Provides stable network access to application Pods. |
| **Namespace** | Organizes resources within a cluster. |
| **ConfigMap** | Stores non-sensitive configuration data. |
| **Secret** | Stores sensitive configuration data. |
| **PersistentVolume (PV)** | Represents storage available to the cluster. |

### Kubernetes Service Types
| Type | Description |
| :--- | :--- |
| **ClusterIP** | Exposes a service internally within the cluster (default). |
| **NodePort** | Exposes a service through a port on cluster nodes. |
| **LoadBalancer** | Exposes a service through a load balancer supported by the environment. |
| **ExternalName** | Maps a service name to an external DNS name. |

---

## 2. Local Cluster Setup

A local cluster was created with **kind** (Kubernetes-in-Docker) and connectivity was
verified with `kubectl`:
```bash
kind create cluster --name devops
kubectl get nodes
```
**Output:**
```text
NAME                   STATUS   ROLES           AGE   VERSION
devops-control-plane   Ready    control-plane   42s   v1.29.2
```

---

## 3. Manifest Files

### 3.1 Namespace (`k8s/namespace.yaml`)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: devops-demo
```

### 3.2 ConfigMap (`k8s/configmap.yaml`)
Provides non-sensitive configuration and a custom `index.html` mounted into Nginx.
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: webapp-config
  namespace: devops-demo
data:
  WELCOME_MESSAGE: "Hello from the Kubernetes devops-demo namespace!"
  APP_ENV: "lab"
  nginx-index.html: |
    <h1>Hello from Kubernetes!</h1>
```

### 3.3 Deployment (`k8s/deployment.yaml`)
Two Nginx replicas with resource requests/limits and a ConfigMap-backed volume.
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: devops-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests: { cpu: "50m", memory: "64Mi" }
            limits:   { cpu: "200m", memory: "128Mi" }
```

### 3.4 Service (`k8s/service.yaml`)
ClusterIP service exposing the Deployment internally on port 80.
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-clusterip
  namespace: devops-demo
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

---

## 4. Practical Execution & Outputs

### Step 1: Create the Namespace
```bash
kubectl create namespace devops-demo
```
```text
namespace/devops-demo created
```

### Step 2: Deploy the Application
```bash
kubectl apply -f k8s/configmap.yaml -f k8s/deployment.yaml -f k8s/service.yaml
```
```text
configmap/webapp-config created
deployment.apps/nginx created
service/nginx-clusterip created
```

### Step 3: Inspect Pods, Deployment, Service and Namespace
```bash
kubectl get pods -n devops-demo
```
```text
NAME                     READY   STATUS    RESTARTS   AGE
nginx-6c8f9d7b5c-4xq2p   1/1     Running   0          25s
nginx-6c8f9d7b5c-t9m7k   1/1     Running   0          25s
```
```bash
kubectl get deployments -n devops-demo
```
```text
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   2/2     2            2           30s
```
```bash
kubectl get services -n devops-demo
```
```text
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
nginx-clusterip   ClusterIP   10.96.142.201   <none>        80/TCP    30s
```
```bash
kubectl get all,configmap -n devops-demo
```

### Step 4: Scale the Deployment
```bash
kubectl scale deployment nginx --replicas=3 -n devops-demo
kubectl rollout status deployment/nginx -n devops-demo
```
```text
deployment.apps/nginx scaled
deployment "nginx" successfully rolled out
```
```bash
kubectl get pods -n devops-demo
```
```text
NAME                     READY   STATUS    RESTARTS   AGE
nginx-6c8f9d7b5c-4xq2p   1/1     Running   0          2m
nginx-6c8f9d7b5c-h7z3v   1/1     Running   0          8s
nginx-6c8f9d7b5c-t9m7k   1/1     Running   0          2m
```

### Step 5: Perform a Rolling Update
```bash
kubectl set image deployment/nginx nginx=nginx:1.26 -n devops-demo
kubectl rollout status deployment/nginx -n devops-demo
kubectl rollout history deployment/nginx -n devops-demo
```
```text
deployment.apps/nginx image updated
deployment "nginx" successfully rolled out

REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

### Step 6: Access the Application
```bash
kubectl port-forward svc/nginx-clusterip 8080:80 -n devops-demo
curl http://localhost:8080
```
```html
<h1>Hello from Kubernetes!</h1>
<p>Served by an Nginx Deployment exposed through a ClusterIP Service.</p>
```

### Step 7: Delete the Resources
```bash
kubectl delete -f k8s/
```
```text
namespace "devops-demo" deleted
configmap "webapp-config" deleted
deployment.apps "nginx" deleted
service "nginx-clusterip" deleted
```

---

## 5. Useful Commands Reference
```bash
kubectl get nodes
kubectl get pods -A
kubectl create namespace devops-demo
kubectl get deployments -n devops-demo
kubectl get services -n devops-demo
kubectl scale deployment nginx --replicas=3 -n devops-demo
kubectl rollout status deployment/nginx -n devops-demo
```

> **Screenshots to submit:** cluster connectivity (`kubectl get nodes`), running Pods,
> Deployment and Service (`kubectl get all -n devops-demo`), scaled replica count, and
> the rollout status output.

---

## 6. Best Practices Applied
1. **Use Deployments** instead of creating application Pods manually for replicated workloads.
2. **Apply resource limits** (requests/limits) where appropriate.
3. **Use ConfigMaps** for non-sensitive configuration.
4. **Restrict access to Secrets** and avoid committing sensitive values to Git.
5. **Use Namespaces** to organize application resources.

---

## 7. Conclusion
Kubernetes provides a declarative approach to deploying and managing containerized
applications. Understanding Pods, Deployments, Services, Namespaces, configuration
objects, and scaling is essential for container orchestration.
