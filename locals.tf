locals {
  tags          = merge(var.tags, { module_name = "tf-module-eks" })
  eks_tags      = merge(local.tags, { Name = "${var.env}-eks" })
  eks_client_id = element(tolist(split("/", tostring(aws_eks_cluster.main.identity[0].oidc[0].issuer))), 4)
}