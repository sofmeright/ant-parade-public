[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/T6T41IT163)

# 🏰 Ad Arbitorium (Datacenter) — Private GitOps Repository

> _"When the cluster's down, and the world is on fire, at least you can still run Ansible."_ 🔥

Welcome to the heart of Ad Arbitorium; a GitOps repository describing the active configuration of our homelab/datacenter. This repo aims to be the source of truth for system state, automation routines, and backup strategies.


---

> Maintained by [SoFMeRight](https://github.com/sofmeright) for [PrPlanIT](https://prplanit.com) — Real world results for your real world expectations.

---

## 📂 Repository Layout

This repository contains:
> (a simple directory structure)
- 🧪 **Ansible Playbooks**: Stored in the `ansible/*/` directory
- 🐧 **Inventory Definitions**: Locate at `ansible/inventory`
- 📦 **Docker Compose Deployments** Stored in the `docker-compose` directory
- 🕸️ **NGINX Proxy Configurations** Stored in the `nginx-extras` directory
- ⚙️ **General Configuration Files** Stored in the `fs` directory
- 💫 **FluxCD Configuration** Located at the `fluxcd` directory
- 💾 **Backup Automation & Recovery Scripts**

Where possible, configuration is version-controlled. In some cases (e.g., Docker volumes or secrets), data resides in protected resources or local mounts.

---

## ⚙️ Automations & Tooling

### 🛠️ Primary Automation: Ansible

We use [Ansible](https://www.ansible.com/) with playbooks stored in this repo and executed via:

- 🔐 [Ansible Semaphore](https://ansible-semaphore.com/) — for web-based job triggering
- 🐳 GitLab CI/CD Components — for automated GitOps-style deployments
- 💡 *Ideas in progress*: OliveTin, or Cronguru for task selection.

### 🗄️ Repository Recovery

> **ant-parade & leaf-cutter** to the rescue! 🐜

If the cluster fails, we can recover from a local repo clone on `leaf-cutter`:

```bash
docker run --rm \
  -v /srv/gitops/ad-arbitorium-private:/srv/gitops/ad-arbitorium-private \
  -v ~/.ssh/id_rsa:/root/.ssh/id_rsa \
  cr.pcfae.com/prplanit/ansible:2.18.6 \
  ansible-playbook --private-key /root/.ssh/id_rsa \
  -i /srv/gitops/ad-arbitorium-private/ansible/inventory \
  /srv/gitops/ad-arbitorium-private/ansible/infrastructure/qemu-guest-agent-debian.yaml
```
## 📅 Backup Schedule

Our peak hours are typically 6:00AM – 10:00PM PST. Backups are scheduled to minimize risk during these times.

| Day           | Time  | Task                                             |
| ------------- | ----- | ------------------------------------------------ |
| Mon, Fri      | 22:00 | NAS & PBS → local-zfs backup                     |
| Tue, Thu, Fri | 23:00 | All other core/essential VMs → Flashy-Fuscia-SSD |

## 🖥️ Hardware Overview

The datacenter is powered by Proxmox VE and consists of five clustered nodes:

| Host           | CPU                                     | RAM                |
| -------------- | --------------------------------------- | ------------------ |
| 🥑 Avocado     | 2× Xeon E5-2680 v3 (24C/48T) 2.5–3.3GHz | 256GB (8×32GB ECC) |
| 🎍 Bamboo      | 2× Xeon E5-2680 v4 (28C/56T) 2.4–3.3GHz | 96GB (6×16GB ECC)  |
| 🌌 Cosmos      | 2× Xeon E5-2667 v3 (16C/32T) 3.2–3.6GHz | 256GB (8×32GB ECC) |
| 🐉 Dragonfruit | AMD Ryzen 7 2700X (8C/16T) 3.7–4.35GHz  | 64GB (2×32GB ECC)  |
| 🍆 Eggplant    | 2× Xeon E5-2683 v3 (28C/56T) 2.0–3.0GHz | 128GB (16×8GB ECC) |

#### 🪲 leaf-cutter (Unclustered automation node)
- CPU: Intel i7-4720HQ (8 threads @ 3.6GHz)
- RAM: 16GB (2×8GB DDR3)
- This node runs critical automation if the cluster fails. Think of it as "ant-parade's stunt double."

## 🧠 Observability & Monitoring
- Grafana + Loki + Prometheus for metrics & logs
- Crowdsec for IDS/IPS and pfsense integration
- Beszel alternative option for metrics
- Wazuh
- Portainer for container management dashboards

## 🌐 Networking Overview

##### Firewall / Routing: 
- Dual HA/CARP pfSense VMs on Avocado & Bamboo

##### Networking:

- OSPFv6 for internal Proxmox/Ceph
- BGP for Kubernetes w/ metallb
- HAProxy load balancing for K8s API
- DNS: Highly available AdGuardHome DNS pair with sync

##### Reverse Proxies:

- cell-membrane, phloem, and xylem handle NGINX proxy duties
> Internal domains like *.pcfae.com live inside xylem (no external exposure)

## 📞 Remote Access Tools
- rustdesk, moonlight, sunshine, tactical-rmm

## 🧱 Core Workloads
- PVE – Bare metal Proxmox hosts
- Ubuntu 24.04 + Docker – Most VMs run containers (including GPU workloads)
- pfSense – Dual-stack IPv4/6 (future: evaluate opnSense again)
- FusionPBX – VOIP System
- Home Assistant OS
- Kubernetes – 5-node cluster, likely reducing to 3 masters soon
- PBS (Proxmox Backup Server)
- Portainer – Jump node: harbormaster
- Shinobi – CCTV & surveillance
- TrueNAS
- Windows Server – Active Directory 3-node forest

## 🔒 VPN / Remote Access

- netbird

## Docker Stacks:

> A full table should be populated with deployments when the pipeline runs and it will be linked to this segment in the near, near future. 

> In the meantime all deployments can be reviewed within the repository.

## 🤓 Want to contribute or improve the stack?
This is a private lab, but feedback, discussion, and memes are always welcome. ✉️

## ⚠️ Disclaimer

> The code, images, and infrastructure templates herein (the "Software") are provided as-is and as-absurd—without warranties, guarantees, or even friendly nudges. The authors accept no liability if this repo makes your cluster self-aware, breaks your ankle (metaphorically or otherwise), or causes irreversible YAML-induced burnout.

We take no responsibility if running this setup somehow:

- launches a container into orbit,

- bricks your homelab,

- or awakens a long-dormant AI from /dev/null.

> Use at your own risk. If it works, thank the open-source gods. If it doesn't, well... you probably learned something.

---

# Past Readme w/ some Wiki type instructions for various tasks:

This repository is responsible for *deployment* of **Kubernetes** Environments and Workloads that are actively managed by SoFMeRight.

This repository is public space, however it is not a product. As such you can depend on its availability on some level as this code is slotted to become essential to SoFMeRight's homelab. However the code contained within this repository is without warranty, you are welcome to raise issues if you wish; no guarantee of any outcome as result however. Having a lab without issues is ideal so it is likely for issues to be addressed. But the scope of this repo is from business to personal and as such it is very paricular the way in which an outside entity might influence the development of this repo. At the very least/especially in these early stages! That being said, if you the person reading this so happen not to be SoFMeRight or internal to PrPlanIT, we don't mean to scare you away! WELCOME to SoFMeRight's K8s lab ~ WIP! Hope you enjoy your stay! 👋🏽


# Quick Reference Commands & Info

## SSH Key Management
To generate pub key: <br>
```ssh-agent sh -c 'ssh-add; ssh-add -L'<br>```
To generate priv key:<br>
```ssh-agent sh -c 'ssh-add; ssh-add -l'<br>```

# Bootstrapping a cephadm cluster.
You will need a number of Linux based machines I used 5 with 2 VMs per each with a master and worker each.
It is advised to transfer ssh keys for password-less authentication and to configure sudo without a prompt.
First we run the script that installs dependencies on each node.
```
bash onboarding/bootstrap-k8s-install-dependencies.sh
```
This next script we run on the first node we intend to assign as a master ~ a control plane node.
```
bash onboarding/bootstrap-k8s-initialize-control-plane.sh
```
If all goes well we should see a message something like:
```
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

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join dungeon-map-001:6443 --token kxgj2w.ucvyopdyulxzdnw4 \
        --discovery-token-ca-cert-hash sha256:6a85476457676767657676677676767677466776547567447d \
        --control-plane 

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join dungeon-map-001:6443 --token kxgj2w.ucvyopdyulxzdnw4 \
        --discovery-token-ca-cert-hash sha25567474567567567567567767676767676767676776764576457fb47d
```
From here you simply use the commands supplied on the corresponding master and worker nodes, but  do prepend with a sudo!
When attempting to add additional control plane nodes I had an issue with needing a single service address so I configured HAProxy within pfSense for this need and set the Virtual IP in the /home/<user>/.kuber/config i.e. "server: https://172.22.22.105:6443".
I also used the following command to label each of my workers accordingly:
```
kubectl label node dungeon-worker-001 node-role.kubernetes.io/worker=worker
```
I had issues with kubernetes-sigs/metrics-server, they were resolved via a variation of these instructions: https://serverfault.com/questions/1153770/installed-metrics-server-in-kubernetes-cluster-but-getting-serviceunavailable
```
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[ \
  { \
    "op": "add", \
    "path": "/spec/template/spec/hostNetwork", \
    "value": true \
  }, \
  { \
    "op": "replace", \
    "path": "/spec/template/spec/containers/0/args", \
    "value": [ \
    "--cert-dir=/tmp", \
    "--secure-port=4443", \
    "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname", \
    "--kubelet-use-node-status-port", \
    "--metric-resolution=15s", \
    "--kubelet-insecure-tls" \
    ] \
  }, \
  { \
    "op": "replace", \
    "path": "/spec/template/spec/containers/0/ports/0/containerPort", \
    "value": 4443 \
  } \
]'
```
# Configuring the Ansible control node for K8s ~ Kustomize testing
First we ssh to a k8s master node and check the running kustomize version.
```
kai@ant-parade:~$ ssh dungeon-map-001
Welcome to Ubuntu 24.04.1 LTS (GNU/Linux 6.8.0-51-generic x86_64)
... ... ...
Last login: Sat Jan 18 10:10:14 2025 from 172.22.22.110
kai@dungeon-map-001:~$ kubectl version
Client Version: v1.31.4
Kustomize Version: v5.4.2
Server Version: v1.31.0
```
After pulling the git we ran the installer.sh we repackaged for convenience.
```
bash Ant_Parade/onboarding/install-kustomize.sh 5.4.2
```
# Bootstrapping fluxcd:
```
flux bootstrap git   --url=ssh://git@<localgitip>:1234/precisionplanit/ant_parade-public   --branch=main   --private-key-file=/root/.ssh/id_rsa   --password=   --path=clusters/overlays/production
```
# Pulling the repo to your local directory:
```
git clone ssh://git@172.22.22.123:2222/PrecisionPlanIT/Ant_Parade.git
```
# Updating the repo after making edits on a local clone:
Check the source repo to compare against our changes.
```
git fetch --all
```
Either merge,
```
git merge origin/main
```
OR rebase (I hear rebase can help to preserve the history a little better perhaps?)
```
git rebase origin/main
```
Now add a commit:
```
git add .
git commit -m "<An optimistic note about something that we promise to be better about.>"
```
On the first run it may ask you to provide info regarding your identity (then retry the previous command):
```
git config --global user.email "kai.hamil@gmail.com"
git config --global user.name "kai"
```
# Push to the source repo
```
git push origin main
```
# Pulling any additional changes occurred after the initial pull.
```
git pull origin main
```
# Sudo does not run without password on target host
Use the ``sudo visudo`` command to edit the permissions for usage of sudo command.
Look for a line that looks like this in the config:
```
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL
```
Update the line to look like such:
```
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) NOPASSWD: ALL
```
# Resolving Ansible "REMOTE HOST IDENTIFICATION HAS CHANGED" issue (Ansible Semaphore)
Use the ``docker exec -it semaphore-semaphore-1 sh`` command to open a shell into the Semaphore docker container.

Edit the ansible configuration file using ``nano /home/semaphore/ansible.cfg``, adapt your current config to contain the following:

```
[defaults]
host_key_checking = False
```
At this point playbooks that fail due to this issue should succeed and we can use an ansible playbook to add this host properly to the known host list.
