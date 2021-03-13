

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.63:6443 --token 2pyun5.0niww8p8l72cwdlp \
    --discovery-token-ca-cert-hash sha256:7c4ad395970f2e1bbe4597bf0abf7fa2c89facc1a3c47f8ce554e44e1d77dfa4


# calico
wget https://docs.projectcalico.org/manifests/tigera-operator.yaml
wget https://docs.projectcalico.org/manifests/custom-resources.yaml
sed -i '' -e 's/192.168/10.0/g' custom-resources.yaml
kubectl taint nodes --all node-role.kubernetes.io/master-

# label workers
kubectl label node k8s2.rsletten.com node-role.kubernetes.io/worker=worker
kubectl label node k8s3.rsletten.com node-role.kubernetes.io/worker=worker
kubectl label node k8s4.rsletten.com node-role.kubernetes.io/worker=worker

# metallb
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.250-192.168.1.250
EOF

# ingress
wget -q -O -  https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/baremetal/deploy.yaml | \
sed -e 's/type: NodePort/type: LoadBalancer/g' | \
kubectl apply -f -

