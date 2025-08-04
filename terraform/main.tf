# terraform/main.tf

# --- FIX 2: Enforce a modern Google Provider version ---
# This ensures that all features for Serverless NEGs are available.
# It's best practice to always define provider versions.
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0" # Use a recent version
    }
  }
}

provider "google" {
  project = var.project_id
  # Region is configured at the resource level where needed.
}

# [Step 0] Create Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.gar_repository_name
  description   = "Docker repository for application images"
  format        = "DOCKER"
}

# Define the Cloud Run service itself
resource "google_cloud_run_v2_service" "main" {
  project  = var.project_id
  name     = var.service_name
  location = var.region

  # This setting restricts traffic to only come from the internal LB and health checks.
  # This corresponds to `--ingress=internal-and-cloud-load-balancing`
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    containers {
      image = var.image_name_with_tag
      ports {
        container_port = 80 # Corresponds to --port 80
      }
    }
  }
}

# --- FIX 1: Manage IAM with a separate resource ---
# The 'iam_policy' block is not valid inside the service definition.
# We create a separate IAM binding resource to allow unauthenticated access.
# This corresponds to the `--allow-unauthenticated` flag.
resource "google_cloud_run_v2_service_iam_binding" "allow_public" {
  project  = google_cloud_run_v2_service.main.project
  location = google_cloud_run_v2_service.main.location
  name     = google_cloud_run_v2_service.main.name

  role = "roles/run.invoker"
  members = [
    "allUsers",
  ]
}

# [Step 1] Create Serverless NEG for the Cloud Run service
# The syntax for a SERVERLESS NEG is correct, but it relies on a modern provider version.
resource "google_compute_region_network_endpoint_group" "neg" {
  project               = var.project_id
  name                  = "neg-for-${var.service_name}"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  # This block links the NEG directly to the Cloud Run service.
  cloud_run {
    service = google_cloud_run_v2_service.main.name
  }
}

# [Step 2 & 3] Create a global Backend Service and add the NEG
resource "google_compute_backend_service" "backend" {
  project     = var.project_id
  name        = "backend-for-${var.service_name}"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  enable_cdn  = false

  backend {
    # Note the change here to use the correct regional NEG resource attribute
    group = google_compute_region_network_endpoint_group.neg.id
  }
}

# [Step 4] Create a URL Map
resource "google_compute_url_map" "url_map" {
  project         = var.project_id
  name            = "lb-url-map-for-${var.service_name}"
  default_service = google_compute_backend_service.backend.id
}

# [Step 5] Reserve a global static IP address
resource "google_compute_global_address" "ip" {
  project = var.project_id
  name    = "lb-static-ip-for-${var.service_name}"
}

# [Step 6] Create a Target HTTP Proxy
resource "google_compute_target_http_proxy" "proxy" {
  project = var.project_id
  name    = "lb-http-proxy-for-${var.service_name}"
  url_map = google_compute_url_map.url_map.id
}

# [Step 7] Create the Global Forwarding Rule (HTTP Load Balancer)
resource "google_compute_global_forwarding_rule" "lb" {
  project    = var.project_id
  name       = "global-lb-for-${var.service_name}"
  target     = google_compute_target_http_proxy.proxy.id
  port_range = "80"
  ip_address = google_compute_global_address.ip.address
}