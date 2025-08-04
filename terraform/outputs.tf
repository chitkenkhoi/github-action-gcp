# terraform/outputs.tf

output "load_balancer_ip" {
  description = "The external IP address of the HTTP Load Balancer."
  value       = google_compute_global_address.ip.address
}

# output "cloud_run_service_url" {
#   description = "The direct URL of the Cloud Run service."
#   value       = google_cloud_run_v2_service.main.uri
# }