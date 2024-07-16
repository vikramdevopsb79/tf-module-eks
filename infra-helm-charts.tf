resource "null_resource" "get-kubeconfig" {

  depends_on = [aws_eks_node_group.node-groups, aws_eks_cluster.main]

  provisioner "local-exec" {
    command = <<EOF
rm -rf ~/.kube
aws eks update-kubeconfig --name "${var.env}-eks"
sleep 300
EOF
  }

}

data "http" "metric-server" {
  url = "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
}

data "kubectl_file_documents" "metric-server" {
  content = data.http.metric-server.body
}

resource "kubectl_manifest" "metric-server" {
  depends_on = [null_resource.get-kubeconfig]

  count     = length(data.kubectl_file_documents.metric-server.documents)
  yaml_body = data.kubectl_file_documents.metric-server.documents[count.index]
}

## Cluster Autoscaler

data "kubectl_file_documents" "cluster-autoscaler" {
  content = file("${path.module}/cluster-autoscale-dev.yaml")
}
output "module_path" {
  value = path.module
}
resource "kubectl_manifest" "cluster-autoscaler" {
  depends_on = [null_resource.get-kubeconfig]

  count     = length(data.kubectl_file_documents.cluster-autoscaler.documents)
  yaml_body = data.kubectl_file_documents.cluster-autoscaler.documents[count.index]
}

# Argocd

resource "kubectl_manifest" "argocd-namespace" {
  depends_on = [null_resource.get-kubeconfig]

  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
YAML
}

data "kubectl_file_documents" "argocd" {
  content = file("${path.module}/argo-${var.env}.yaml")
}

resource "kubectl_manifest" "argocd" {
  depends_on = [null_resource.get-kubeconfig, kubectl_manifest.argocd-namespace]

  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = data.kubectl_file_documents.argocd.documents[count.index]
  override_namespace = "argocd"
}

## Nginx Ingress

resource "null_resource" "nginx-ingress" {
  depends_on = [null_resource.get-kubeconfig]

  provisioner "local-exec" {
    command = <<EOF
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade -i ngx-ingres ingress-nginx/ingress-nginx -f ${path.module}/nginx-ingress.yaml
EOF
  }

}

## External DNS
data "kubectl_file_documents" "external-dns" {
  content = file("${path.module}/external-dns.yaml")
}

resource "kubectl_manifest" "external-dns" {
  depends_on = [null_resource.get-kubeconfig]

  count              = length(data.kubectl_file_documents.external-dns.documents)
  yaml_body          = data.kubectl_file_documents.external-dns.documents[count.index]
}