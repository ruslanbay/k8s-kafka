# Test Environment: Kubernetes, Apache Kafka 4.0, MirrorMaker 2.0, Monitoring and Jmeter

## Virtual Machine Deployment

```shell
VM_NAME=alpine-k0s
VM_DIR="${HOME}/VMs"
CPU_CORES=2
RAM_SIZE=6G
DISK_SIZE=15G
DISK_PATH="${VM_DIR}/${VM_NAME}.qcow2"

mkdir -p "${VM_DIR}"

ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.0-x86_64.iso"
ISO_PATH="${VM_DIR}/alpine-virt-3.22.0-x86_64.iso"

[ ! -f "$ISO_PATH" ] && curl -L -o "$ISO_PATH" "$ISO_URL"

[ ! -f "$DISK_PATH" ] && qemu-img create -f qcow2 "$DISK_PATH" $DISK_SIZE

qemu-system-x86_64 \
  -name "$VM_NAME" \
  -machine type=q35,accel=kvm \
  -enable-kvm \
  -cpu host \
  -smp $CPU_CORES \
  -m $RAM_SIZE \
  -drive file="$DISK_PATH",if=virtio,format=qcow2 \
  -cdrom "$ISO_PATH" \
  -netdev user,id=net0,hostfwd=tcp::8443-:8443,hostfwd=tcp::3000-:3000 \
  -device virtio-net-pci,netdev=net0 \
  -nographic
```

## Install and Setup Alpine Linux <sup>[docs](https://wiki.alpinelinux.org/wiki/Alpine_setup_scripts#setup-alpine)</sup>

To install Alpine linux run `setup-apline`. The script walks you interactively through configuring keyboard layout, hostname, network, root password, timezone, and other settings.

You can automate the installaion process by creating an answerfile that contains predefined answers to all the prompts: `setup-apline -f answerfile.txt`

```shell
# Example answer file for setup-alpine script
# If you don't want to use a certain option, then comment it out

# Use US layout with US variant
# KEYMAPOPTS="us us"
KEYMAPOPTS=none

# Set hostname to 'alpine'
HOSTNAMEOPTS=alpine

# Set device manager to mdev
DEVDOPTS=mdev

# Contents of /etc/network/interfaces
INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
hostname alpine-test
"

# Search domain of example.com, Google public nameserver
# DNSOPTS="-d example.com 8.8.8.8"

# Set timezone to UTC
#TIMEZONEOPTS="UTC"
TIMEZONEOPTS=none

# set http/ftp proxy
#PROXYOPTS="http://webproxy:8080"
PROXYOPTS=none

# Add first mirror (CDN)
APKREPOSOPTS="-1"

# Create admin user
USEROPTS="-a -u -g audio,input,video,netdev juser"
#USERSSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIiHcbg/7ytfLFHUNLRgEAubFz/13SwXBOM/05GNZe4 juser@example.com"
#USERSSHKEY="https://example.com/juser.keys"

# Install Openssh
SSHDOPTS=openssh
#ROOTSSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIiHcbg/7ytfLFHUNLRgEAubFz/13SwXBOM/05GNZe4 juser@example.com"
#ROOTSSHKEY="https://example.com/juser.keys"

# Use openntpd
# NTPOPTS="openntpd"
NTPOPTS=none

# Use /dev/sda as a sys disk
# DISKOPTS="-m sys /dev/sda"
DISKOPTS=none

# Setup storage with label APKOVL for config storage
#LBUOPTS="LABEL=APKOVL"
LBUOPTS=none

#APKCACHEOPTS="/media/LABEL=APKOVL/cache"
APKCACHEOPTS=none
```

After the installation is complete the system may be power-cycled or rebooted to confirm everything is working correctly. The relevant commands for this are `poweroff` or `reboot`. Login into the new system with the root account.

## Install Packages

```shell
apk add \
    bash \
    curl \
    envsubst \
    git \
    helm \
    zram-init
```

Make sure you're using Helm 3.18.1 or above, otherwise you may face some issues: [1](https://github.com/helm/helm/commit/bec66098fdb4ac37298f46701a2d5b28e5776b72), [2](https://github.com/prometheus-community/helm-charts/issues/467#issuecomment-1649313971), [3](https://github.com/prometheus-community/helm-charts/issues/467#issuecomment-1241426318)

`helm version`

Helm has an [installer script](https://helm.sh/docs/intro/install/#from-script) that will automatically grab the latest version of Helm and install it locally. You can fetch that script, and then execute it locally. It's well documented so that you can read through it and understand what it is doing before you run it.

```bash
HELM_VERSION=v3.18.3

curl "https://raw.githubusercontent.com/helm/helm/${HELM_VERSION}/scripts/get-helm-3" | bash

'echo "alias helm=/usr/local/bin/helm"' >> ~/.profile
```

## Enable Zram <sup>[docs](https://wiki.alpinelinux.org/wiki/Zram)</sup>

The zram module creates RAM-based block devices named /dev/zram<id> (<id> = 0, 1, ...). Pages written to these disks are compressed and stored in memory itself. These disks allow very fast I/O and compression provides good amounts of memory savings.

For a basic ZRAM swap, configure ZRAM by editing the file `/etc/conf.d/zram-init` as follows:

```shell
load_on_start=yes
unload_on_stop=yes
num_devices=1

type0=swap
flag0= # The default "16383" is fine for us

size0=`LC_ALL=C free -m | awk '/^Mem:/{print int($2/1)}'`
mlim0= # no hard memory limit
back0= # no backup device
icmp0= # no incompressible page writing to backup device
idle0= # no idle page writing to backup device
wlim0= # no writeback_limit for idle page writing for backup device
notr0= # keep the default on linux-3.15 or newer
maxs0=1 # maximum number of parallel processes for this device
algo0=zstd # zstd (since linux-4.18), lz4 (since linux-3.15), or lzo.
           # Size: zstd (best) > lzo > lz4. Speed: lz4 (best) > zstd > lzo
labl0=zram_swap # the label name
uuid0= # Do not force UUID
args0= # we could e.g. have set args0="-L 'zram_swap'" instead of using labl0
```

Start services:
```shell
rc-service zram-init start
```

To ensure that service starts during next reboot:
```shell
rc-update add zram-init
```

## Deploy k0s <sup>[docs](https://docs.k0sproject.io/stable/install/)</sup>

k0s is an open source, all-inclusive Kubernetes distribution, which is configured with all of the features needed to build a Kubernetes cluster and packaged as a single binary for ease of use.

```shell
curl -sSf https://get.k0s.sh | sh
k0s install controller --single # --disable-components metrics-server
k0s start
k0s status

echo "alias k='k0s kubectl'" >> ~/.profile

k get nodes
```

## Deploy Strimzi Using Installation Files <sup>[docs](https://strimzi.io/quickstarts/)</sup>

Strimzi simplifies the process of running Apache Kafka within a Kubernetes cluster through a set of specialized operators:
* **Cluster Operator** handles the lifecycle of Kafka clusters, ensuring smooth deployment and management. If you're running the Cluster Operator, you can also use the Drain Cleaner to assist with pod evictions.
* **Topic Operator** manages Kafka topics, making it easy to create, update, and delete topics.
* **User Operator** manages Kafka users, including authentication credentials.

Before deploying the Strimzi cluster operator, create a namespace called kafka:
```shell
k0s kubectl create namespace kafka
```

Apply the Strimzi install files:

```shell
k0s kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
```

Follow the deployment of the Strimzi cluster operator:
```shell
k0s kubectl get pod -n kafka --watch
```

You can also follow the operator’s log:
```shell
k0s kubectl logs deployment/strimzi-cluster-operator -n kafka -f
```

## Deploy Main and Backup Kafka Clusters <sup>[docs](https://github.com/strimzi/strimzi-kafka-operator/tree/0.46.1/examples/kafka)</sup>

```shell
git clone https://github.com/ruslanbay/k8s-kafka -b kafka-4.0.0
```

### Main Kafka Cluster

Deploy a Kafka cluster with one pool of KRaft nodes that share the broker and controller roles:
```shell
k0s kubectl -n kafka apply -f k8s-kafka/kafka-cluster.yaml
```

### Backup Kafka Cluster

Deploy a backup Kafka cluster with a single Kafka node that has both broker and controller roles:
```shell
k0s kubectl -n kafka apply -f k8s-kafka/kafka-backup-cluster.yaml
```

### Configuring Kafka MirrorMaker 2 <sup>[1](https://strimzi.io/docs/operators/latest/deploying#con-config-mirrormaker2-str) [2](https://strimzi.io/docs/operators/latest/configuring.html#type-KafkaMirrorMaker2-reference) [3](https://developers.redhat.com/articles/2023/11/13/demystifying-kafka-mirrormaker-2-use-cases-and-architecture)</sup>

MirrorMaker is a tool from the Apache Kafka project designed for replicating and streaming data between Kafka clusters with enhanced efficiency, scalability, and fault tolerance.

We're going to set up disaster recovery in an active/passive configuration.

```shell
k0s kubectl -n kafka apply -f k8s-kafka/kafka-mirror-maker2.yaml
```

## Monitoring

### Kubernetes Dashboard

#### Install Kubernetes Dashboard <sup>[docs](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)</sup>

```bash
# Add kubernetes-dashboard repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

mkdir -p "${HOME}/.kube/"
k0s kubeconfig admin > "${HOME}/.kube/config"

# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
```

#### Accessing the Dashboard UI <sup>[docs](https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md)</sup>

To protect your cluster data, Dashboard deploys with a minimal RBAC configuration by default. Currently, Dashboard only supports logging in with a Bearer Token.

> **WARNING**
The sample user created in the tutorial will have administrative privileges and is for educational purposes only.

To create a sample user for this demo execute the following command:

```shell
k0s kubectl apply -f service-account.yaml
```

Now we need to find the token we can use to log in. Execute the following command:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

It should print something like:

```
eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9...
```

To access Dashboard from the host machine run:
```shell
k0s kubectl -n kubernetes-dashboard port-forward --address=0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443

# NOTE: In case port-forward command does not work, make sure that kong service name is correct.
# Check the services in Kubernetes Dashboard namespace using:
k0s kubectl -n kubernetes-dashboard get svc
```

From your host machine navigate to the following page and authenticate using the token:

https://localhost:8443/#/pod?namespace=kubernetes-dashboard

### Install Prometheus and Grafana <sup>[docs](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)</sup>

```shell
k0s kubectl create namespace monitoring

helm install -n monitoring \
  prometheus prometheus-community/kube-prometheus-stack \
  --set prometheus-node-exporter.hostRootFsMount.enabled=false \
  --set grafana.service.port=3000 \
  --set grafana.service.targetPort=3000
```

#### Accessing Grafana

```shell
k0s kubectl -n monitoring port-forward --address=0.0.0.0 svc/prometheus-grafana 3000:3000
```

Get the Grafana admin password:
```shell
k0s kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

From your host machine navigate to the following page and authenticate using the admin password:

http://localhost:3000/login

You can use metrics and dashboards from the Strimzi examples repository to monitor your Kafka clusters:

* https://github.com/strimzi/strimzi-kafka-operator/tree/main/examples

* https://github.com/strimzi/strimzi-kafka-operator/blob/main/examples/metrics/kafka-metrics.yaml

* https://github.com/strimzi/strimzi-kafka-operator/blob/main/examples/metrics/grafana-dashboards/strimzi-kafka.json


## Jmeter

Create a single replica pod running two containers named consumer and producer, both based on the same [k8s-kafka image](https://ghcr.io/ruslanbay/k8s-kafka:latest).

```shell
export TESTS_PATH=/root/k8s-kafka/tests

envsubst < k8s-kafka/jmeter-deployment.yaml | k0s kubectl -n kafka apply -f -
```

This deployment is intended for Kafka performance and load testing using JMeter scripts. It runs both a producer and a consumer client in the same pod to simulate message production and consumption on a Kafka topic, leveraging mounted test scripts and certificates for secure communication.