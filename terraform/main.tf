# terraform/main.tf

provider "google" {
  project = var.project_id
  region  = var.region
}

# [Step 0] Create Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.gar_repository_name
  description   = "Docker repository for application images"
  format        = "DOCKER"
}

# Define the Cloud Run service itself
# We manage the service definition here, but update the image in the deployment pipeline
resource "google_cloud_run_v2_service" "main" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" # Matches your --ingress flag

  template {
    containers {
      image = var.image_name_with_tag
      ports {
        container_port = 80 # Matches your --port flag
      }
    }
  }

  # This allows the LB health checks and public access via the LB
  iam_policy {
    policy_data = data.google_iam_policy.allow_public.policy_data
  }
}

# IAM policy to allow unauthenticated access to the Cloud Run service
# This is equivalent to --allow-unauthenticated
data "google_iam_policy" "allow_public" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

# [Step 1] Create Serverless NEG for Cloud Run
resource "google_compute_network_endpoint_group" "neg" {
  name                  = "neg-for-${var.service_name}"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_v2_service.main.name
  }
}

# [Step 2 & 3] Create a global Backend Service and add the NEG
resource "google_compute_backend_service" "backend" {
  name        = "backend-for-${var.service_name}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = false
  backend {
    group = google_compute_network_endpoint_group.neg.id
  }
}

# [Step 4] Create a URL Map
resource "google_compute_url_map" "url_map" {
  name            = "lb-url-map-for-${var.service_name}"
  default_service = google_compute_backend_service.backend.id
}

# [Step 5] Reserve a global static IP address
resource "google_compute_global_address" "ip" {
  name = "lb-static-ip-for-${var.service_name}"
}

# [Step 6] Create a Target HTTP Proxy
resource "google_compute_target_http_proxy" "proxy" {
  name    = "lb-http-proxy-for-${var.service_name}"
  url_map = google_compute_url_map.url_map.id
}

# [Step 7] Create the Global Forwarding Rule (HTTP Load Balancer)
resource "google_compute_global_forwarding_rule" "lb" {
  name       = "global-lb-for-${var.service_name}"
  target     = google_compute_target_http_proxy.proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.ip.address
}