# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster
#
# Set the configuration of Managed Service for Kubernetes cluster

locals {
  zone_a_v4_cidr_blocks = "10.1.0.0/16"   # Set the CIDR block for subnet in the ru-central1-a availability zone.
  cluster_ipv4_cidr     = "10.112.0.0/16" # Set IP range for allocating pod addresses.
  service_ipv4_cidr     = "10.96.0.0/16"  # Set IP range for allocating service addresses.
  k8s_version           = "1.33"              # Set the Kubernetes version.
  sa_name               = "k8s-sa"              # Set a service account name. It must be unique within the cloud.
}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for Kubernetes cluster"
  name        = "k8s-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "k8s-cluster-nodegroup-traffic" {
  description = "The group rules allow service traffic for the cluster and node groups. Apply the rules to the cluster and the node groups."
  name        = "k8s-cluster-nodegroup-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description       = "Rule for health checks of the network load balancer."
    from_port         = 0
    to_port           = 65535
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }
  ingress {
    description       = "Rule for incoming service traffic between the master and the nodes."
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
  ingress {
    description    = "Rule for health checks of nodes using ICMP requests from subnets within Yandex Cloud."
    protocol       = "ICMP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  }
  egress {
    description       = "Rule for outgoing service traffic between the master and the nodes."
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
}

resource "yandex_vpc_security_group" "k8s-nodegroup-traffic" {
  description = "The group rules allow service traffic for the node groups. Apply the rules to the node groups."
  name        = "k8s-nodegroup-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "Rule for incoming traffic that allows traffic transfer between pods and services."
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = [local.cluster_ipv4_cidr, local.service_ipv4_cidr]
  }
  egress {
    description    = "Rule for outgoing traffic that allows node group nodes to connect to external resources."
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-services-access" {
  name        = "k8s-services-access"
  description = "The group rules allow connections to services from the Internet. Apply it to node groups."
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "The rule allows incoming traffic in order to connect to Kubernetes services."
    from_port      = 30000
    to_port        = 32767
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-ssh-access" {
  description = "The group rules allow connection to nodes via SSH. Apply it to node groups."
  name        = "k8s-ssh-access"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "Rule for incoming traffic that allows connection to nodes via SSH."
    port           = 22
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-cluster-traffic" {
  description = "The group rules allow traffic for the cluster. Apply the rules to the cluster."
  name        = "k8s-cluster-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "Rule for incoming traffic that allows access to the Kubernetes API (port 443)."
    port           = 443
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "Rule for incoming traffic that allows access to the Kubernetes API (port 6443)."
    port           = 6443
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description    = "Rule for outgoing traffic that allows traffic transfer between the master and metric-server pods."
    port           = 4443
    protocol       = "TCP"
    v4_cidr_blocks = [local.cluster_ipv4_cidr]
  }
}

resource "yandex_iam_service_account" "k8s-sa" {
  name = local.sa_name
}

resource "yandex_resourcemanager_folder_iam_binding" "k8s-clusters-agent" {
  # Assign the "k8s.clusters.agent" role to the service account
  folder_id = var.folder_id
  role      = "k8s.clusters.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "k8s-tunnelClusters-agent" {
  # Assign the "k8s.tunnelClusters.agent" role to the service account
  folder_id = var.folder_id
  role      = "k8s.tunnelClusters.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "vpc-publicAdmin" {
  # Assign the "vpc.publicAdmin" role to the service account
  folder_id = var.folder_id
  role      = "vpc.publicAdmin"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "images-puller" {
  # Assign the "container-registry.images.puller" role to the service account
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "lb-admin" {
  # Assign the "load-balancer.admin" role to the service account
  folder_id = var.folder_id
  role      = "load-balancer.admin"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Managed Service for Kubernetes cluster
resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description        = "Managed Service for Kubernetes cluster"
  name               = "k8s-cluster"
  network_id         = yandex_vpc_network.k8s-network.id
  cluster_ipv4_range = local.cluster_ipv4_cidr
  service_ipv4_range = local.service_ipv4_cidr

  master {
    version = local.k8s_version
    master_location {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }

    public_ip = true

    security_group_ids = [
      yandex_vpc_security_group.k8s-cluster-nodegroup-traffic.id,
      yandex_vpc_security_group.k8s-cluster-traffic.id
    ]

  }
  service_account_id      = yandex_iam_service_account.k8s-sa.id # Cluster service account ID
  node_service_account_id = yandex_iam_service_account.k8s-sa.id # Node group service account ID
  depends_on = [
    yandex_resourcemanager_folder_iam_binding.k8s-clusters-agent,
    yandex_resourcemanager_folder_iam_binding.k8s-tunnelClusters-agent,
    yandex_resourcemanager_folder_iam_binding.vpc-publicAdmin,
    yandex_resourcemanager_folder_iam_binding.images-puller,
    yandex_resourcemanager_folder_iam_binding.lb-admin
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for Managed Service for Kubernetes cluster"
  name        = "k8s-node-group"
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  version     = local.k8s_version

  scale_policy {
    fixed_scale {
      size = 1 # Number of hosts
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-a"
    }
  }

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.subnet-a.id]
      security_group_ids = [
        yandex_vpc_security_group.k8s-cluster-nodegroup-traffic.id,
        yandex_vpc_security_group.k8s-nodegroup-traffic.id,
        yandex_vpc_security_group.k8s-services-access.id,
        yandex_vpc_security_group.k8s-ssh-access.id,
      ]
    }

    resources {
      memory = 4 # RAM quantity in GB
      cores  = 4 # Number of CPU cores
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # Disk size in GB
    }
  }
}