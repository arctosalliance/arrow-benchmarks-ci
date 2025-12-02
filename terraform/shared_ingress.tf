# Shared Ingress for both Conbench and Arrow BCI
# This uses the existing conbench LoadBalancer to route traffic to both services

# Create a Kubernetes Ingress that routes traffic based on hostname
# to both conbench-service and arrow-bci-service through the same ELB

resource "kubernetes_ingress_v1" "shared_ingress" {
  metadata {
    name      = "shared-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                    = "nginx"
      "nginx.ingress.kubernetes.io/ssl-redirect"      = "true"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    }
  }

  spec {
    tls {
      hosts = [
        "conbench.arrow-dev.org",
        "arrow-bci.arrow-dev.org"
      ]
      secret_name = "arrow-dev-tls"
    }

    rule {
      host = "conbench.arrow-dev.org"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "conbench-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "arrow-bci.arrow-dev.org"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "arrow-bci-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service.arrow_bci
  ]
}

