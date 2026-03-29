resource "null_resource" "kubeconfig" {
  depends_on = [yandex_kubernetes_cluster.k8s-cluster]

  provisioner "local-exec" {
    command = "yc managed-kubernetes cluster get-credentials --name k8s-cluster --external --force"
  }
}