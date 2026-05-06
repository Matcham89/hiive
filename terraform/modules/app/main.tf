resource "kubernetes_namespace" "app" {
  metadata {
    name = "hello-world"
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

resource "kubernetes_config_map" "html" {
  metadata {
    name      = "hello-world-html"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    "index.html" = <<-HTML
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="UTF-8" />
          <title>Hello from EKS</title>
          <style>
            body { font-family: sans-serif; display: flex; justify-content: center;
                   align-items: center; height: 100vh; margin: 0; background: #0f172a; color: #e2e8f0; }
            .card { text-align: center; padding: 2rem 3rem; border: 1px solid #334155;
                    border-radius: 8px; background: #1e293b; }
            h1 { color: #38bdf8; margin-bottom: 0.5rem; }
            p  { color: #94a3b8; margin: 0.25rem 0; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Hello from EKS</h1>
            <p>Cluster: <strong>${var.cluster_name}</strong></p>
            <p>Environment: <strong>${var.environment}</strong></p>
          </div>
        </body>
      </html>
    HTML
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app         = "hello-world"
      environment = var.environment
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "hello-world"
      }
    }

    template {
      metadata {
        labels = {
          app         = "hello-world"
          environment = var.environment
        }
      }

      spec {
        container {
          name  = "nginx"
          image = var.image

          port {
            container_port = 80
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.html.metadata[0].name
          }
        }
      }
    }
  }
}

# ClusterIP — intentionally not exposed to the internet
resource "kubernetes_service" "app" {
  metadata {
    name      = "hello-world"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app = "hello-world"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
