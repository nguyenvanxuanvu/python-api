- Update 
```
sudo yum update -y
sudo yum install -y curl tar gzip openssh-clients
```




- Install kubectl 
```
K8S_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
kubectl version --client
```


- Install kustomize
```
KUSTOMIZE_VERSION="v5.4.2"
curl -sSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" | tar -xz
chmod +x kustomize
sudo mv kustomize /usr/local/bin/kustomize
kustomize version
```

- Create kubeconfig:
```
mkdir -p ~/.kube
touch ~/.kube/config
chmod 700 ~/.kube
chmod 600 ~/.kube/config
```

- Create working kubeconfig/context. That step installs K3s, which is a lightweight Kubernetes distribution.
    Kubernetes control plane and node components
    Container runtime: containerd (not Docker)
    kubectl config at /etc/rancher/k3s/k3s.yaml


```
set -e

# 1) install/start k3s (single-node Kubernetes)
curl -sfL https://get.k3s.io | sh -
sudo systemctl enable --now k3s

# 2) make kubeconfig for ec2-user
mkdir -p /home/ec2-user/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config
chmod 700 /home/ec2-user/.kube
chmod 600 /home/ec2-user/.kube/config

# 3) verify
kubectl config get-contexts
kubectl get nodes -o wide
kubectl get ns
```









# About Github:
- Set up Secrets and Varibables