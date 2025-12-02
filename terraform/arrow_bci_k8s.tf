# Arrow BCI Kubernetes Resources
# This file defines the Kubernetes resources for the Arrow BCI application

# ConfigMap for Arrow BCI configuration
resource "kubernetes_config_map" "arrow_bci" {
  metadata {
    name = "arrow-bci-config"
    labels = {
      app = "arrow-bci"
    }
  }

  data = {
    BUILDKITE_API_BASE_URL                  = var.buildkite_api_base_url
    BUILDKITE_ORG                           = var.buildkite_org
    CONBENCH_URL                            = var.conbench_url
    DB_HOST                                 = aws_db_instance.arrow_bci.address
    DB_PORT                                 = tostring(aws_db_instance.arrow_bci.port)
    DB_NAME                                 = var.db_name_arrow_bci
    ENV                                     = var.environment
    FLASK_APP                               = var.flask_app
    GITHUB_API_BASE_URL                     = var.github_api_base_url
    GITHUB_REPO                             = var.github_repo
    GITHUB_REPO_WITH_BENCHMARKABLE_COMMITS  = var.github_repo_with_benchmarkable_commits
    MAX_COMMITS_TO_FETCH                    = var.max_commits_to_fetch
    PIPY_API_BASE_URL                       = var.pypi_api_base_url
    PIPY_PROJECT                            = var.pypi_project
    SLACK_API_BASE_URL                      = var.slack_api_base_url
  }

  depends_on = [
    aws_eks_cluster.conbench,
    aws_eks_node_group.conbench
  ]
}

# Secret for Arrow BCI sensitive data
resource "kubernetes_secret" "arrow_bci" {
  metadata {
    name = "arrow-bci-secrets"
  }

  data = {
    DB_USERNAME         = aws_db_instance.arrow_bci.username
    DB_PASSWORD         = var.db_password  # Use the same password variable
    BUILDKITE_API_TOKEN = var.buildkite_api_token
    GITHUB_API_TOKEN    = var.github_api_token
    SLACK_API_TOKEN     = var.slack_api_token
  }

  depends_on = [
    aws_eks_cluster.conbench,
    aws_eks_node_group.conbench
  ]
}

# Deployment for Arrow BCI application
resource "kubernetes_deployment" "arrow_bci" {
  metadata {
    name = "arrow-bci-deployment"
    labels = {
      app = "arrow-bci"
    }
  }

  spec {
    replicas = var.arrow_bci_replicas

    selector {
      match_labels = {
        app = "arrow-bci"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "25%"
      }
    }

    template {
      metadata {
        labels = {
          app = "arrow-bci"
        }
      }

      spec {
        container {
          name    = "arrow-bci"
          image   = var.arrow_bci_image
          command = ["gunicorn", "-b", "0.0.0.0:5000", "-w", "5", "app:app", "--access-logfile=-", "--error-logfile=-", "--preload"]

          image_pull_policy = "Always"

          port {
            container_port = 5000
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.arrow_bci.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.arrow_bci.metadata[0].name
            }
          }

          readiness_probe {
            http_get {
              path   = "/health-check"
              port   = 5000
              scheme = "HTTP"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 20
            success_threshold     = 2
            failure_threshold     = 1
          }

          liveness_probe {
            http_get {
              path   = "/health-check"
              port   = 5000
              scheme = "HTTP"
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        termination_grace_period_seconds = 5
      }
    }
  }

  depends_on = [
    kubernetes_config_map.arrow_bci,
    kubernetes_secret.arrow_bci
  ]
}

# Service for Arrow BCI (LoadBalancer - shares same ELB as conbench via host-based routing)
resource "kubernetes_service" "arrow_bci" {
  metadata {
    name      = "arrow-bci-service"
    namespace = "default"
    annotations = {
      # Use the same load balancer as conbench by setting the same service name
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"         = aws_acm_certificate.arrow_dev.arn
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"        = "443"
    }
    labels = {
      app = "arrow-bci"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "arrow-bci"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 5000
      protocol    = "TCP"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 5000
      protocol    = "TCP"
    }
  }

  depends_on = [
    kubernetes_deployment.arrow_bci
  ]
}

# Ingress for Arrow BCI - commented out since using LoadBalancer instead
# Requires ALB Ingress Controller which is not currently installed
# resource "kubernetes_ingress_v1" "arrow_bci" {
#   metadata {
#     name      = "arrow-bci-ingress"
#     namespace = "default"
#     annotations = {
#       "kubernetes.io/ingress.class" : "alb"
#       "alb.ingress.kubernetes.io/scheme" : "internet-facing"
#       "alb.ingress.kubernetes.io/target-type" : "ip"
#       "alb.ingress.kubernetes.io/certificate-arn" : aws_acm_certificate.arrow_dev.arn
#     }
#   }
#
#   spec {
#     ingress_class_name = "alb"
#     rule {
#       host = "arrow-bci.arrow-dev.org"
#       http {
#         path {
#           path = "/"
#           path_type = "Prefix"
#           backend {
#             service {
#               name = "arrow-bci-service"
#               port {
#                 number = 80
#               }
#             }
#           }
#         }
#       }
#     }
#     tls {
#       hosts = ["arrow-bci.arrow-dev.org"]
#       secret_name = "arrow-bci-tls"
#     }
#   }
#
#   depends_on = [
#     kubernetes_service.arrow_bci
#   ]
# }

# Route53 record for Arrow BCI pointing to its LoadBalancer
# Note: After applying this, you'll need to get the ELB DNS name from:
# kubectl get svc arrow-bci-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
# Then update var.arrow_bci_elb_dns_name in terraform.tfvars
resource "aws_route53_record" "arrow_bci" {
  count   = var.arrow_bci_create_dns_record ? 1 : 0
  zone_id = data.aws_route53_zone.arrow_dev.zone_id
  name    = "arrow-bci.arrow-dev.org"
  type    = "A"

  alias {
    name                   = var.arrow_bci_elb_dns_name
    zone_id                = var.elb_zone_id
    evaluate_target_health = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

