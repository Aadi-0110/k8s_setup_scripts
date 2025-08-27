```markdown
# Kubernetes Quick-Start Scripts (NIC-aware, **Bare-Metal** Edition)

These four Bash scripts turn a clean Ubuntu 22.04 / Debian 12 server farm into a small kubeadm cluster that

* asks **which network interface** (e.g. `eno1`, `enp3s0`) should carry all
  cluster traffic and forces the kubelet to advertise only that IP (`--node-ip`)
* pins **Flannel** to the same interface (`FLANNELD_IFACE`) so pod-to-pod
  traffic never leaks onto the wrong VLAN or Wi-Fi
* optionally **removes the NoSchedule taint** so the master node can run
  regular workloads &nbsp;—&nbsp; off by default (best practice [^113])
* provides a **one-command reset** that wipes Kubernetes from a node

---

## File overview

| Script                     | Run on            | Purpose                                                                                              |
|----------------------------|-------------------|------------------------------------------------------------------------------------------------------|
| `install-k8s-common.sh`    | **all nodes**     | Install containerd + kubelet/kubeadm/kubectl, disable swap, load kernel modules, prompt for NIC      |
| `init-master.sh`           | **first master**  | `kubeadm init`, deploy Flannel pinned to NIC, optional taint removal, print join command              |
| `join-worker.sh`           | **each worker**   | Ask for the join command and execute it; inherits NIC settings created by the common script          |
| `reset-k8s.sh`             | any node          | Clean uninstallation: `kubeadm reset -f` + delete CNI, PKI, node-IP drop-ins and NIC cache            |

---

## Prerequisites

* Two or more **bare-metal** servers running Ubuntu 22.04 LTS or Debian 12
* Outbound Internet access (APT + Flannel manifest) on at least one interface
* Passwordless `sudo` for the user running the scripts
* Open firewall between nodes on:  
  `6443` (🡒 API server) &nbsp;|&nbsp; `2379-2380` (etcd) &nbsp;|&nbsp; `10250` (kubelet)  
  plus the pod-network CIDR (`10.244.0.0/16` by default)
* (Optional but recommended) DHCP reservation or static IPs for all nodes

---

## Quick start (copy + paste)

```


# 1 – Common setup on every node

chmod +x install-k8s-common.sh
./install-k8s-common.sh            \# pick the NIC when prompted

# 2 – Bootstrap the control plane on ONE node

chmod +x init-master.sh
./init-master.sh                   \# decide if the master may run workloads

# ➜ copy the printed kubeadm join command

# 3 – Join each worker

chmod +x join-worker.sh
./join-worker.sh                   \# paste the join command

# 4 – Verify
```
kubectl get nodes -o wide
```

## What the scripts actually do

| Step | Action |
|------|--------|
| **NIC prompt** | User types an interface name once; script stores `/etc/k8s-iface/{nic,ip}`. |
| `--node-ip`    | Creates a kubelet drop-in so the node always registers that specific IP. |
| containerd     | Generates `/etc/containerd/config.toml`, sets `SystemdCgroup = true`, restarts & enables the service. |
| Kernel prep    | Loads `overlay` + `br_netfilter`, enables forwarding, disables swap permanently. |
| `kubeadm init` | Runs with `--apiserver-advertise-address =<NIC IP>` and default Flannel pod CIDR `10.244.0.0/16`. |
| CNI pinning    | Patches the Flannel DaemonSet to include `FLANNELD_IFACE=<NIC>`. |
| Optional taint | Prompts **“Allow regular pods on the master? [y/N]”** and removes the control-plane taint if you answer `y`. |
| Worker join    | Uses the same node-IP drop-in; no extra flags needed. |
| Reset          | `kubeadm reset -f`, stops kubelet, purges `/etc/kubernetes`, PKI, CNI, and the stored NIC cache. |

---

## Configuration knobs

| Variable      | File            | Default          | Note                                              |
|---------------|-----------------|------------------|---------------------------------------------------|
| `POD_CIDR`    | `init-master.sh`| `10.244.0.0/16`  | Must match your CNI; leave if you use Flannel.    |
| `SVC_CIDR`    | `init-master.sh`| `10.96.0.0/12`   | Change only if it overlaps with your LAN.         |
| `k8s.lab.local`| `init-master.sh`| Placeholder      | Replace with a DNS record if you have local DNS.  |

---

## Typical bare-metal network choices

| If your servers have…          | Answer NIC prompt with… | Result |
|--------------------------------|-------------------------|--------|
| 1 × 1 GbE port on LAN          | `enp2s0`                | Cluster + Internet share the same interface. |
| 2 × NICs — LAN + isolated VLAN | the VLAN NIC            | All pod & service traffic stays on the private VLAN; OS updates still work over the LAN NIC. |
| Wired LAN + onboard Wi-Fi      | the wired NIC (`eno1`)  | Cluster traffic gets reliable Ethernet; Wi-Fi is untouched. |

---

## Tear-down / rebuild

```

./reset-k8s.sh      \# run on the node to wipe
reboot
./install-k8s-common.sh

```

---

## License

MIT — copy, modify, break, fix, enjoy.