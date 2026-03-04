resource "kubernetes_namespace" "demo_app" {
  metadata {
    name = "demo-app"
    labels = {
      "app.kubernetes.io/name" = "demo-app"
    }
  }
}
