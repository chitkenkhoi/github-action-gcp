# terraform/variables.tf

variable "project_id" {
  description = "The Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "The region for the resources."
  type        = string
}

variable "service_name" {
  description = "The name of the Cloud Run service."
  type        = string
}

variable "gar_repository_name" {
  description = "The name of the Artifact Registry repository."
  type        = string
}

variable "image_name_with_tag" {
  description = "The full name of the container image to deploy, including the tag/digest."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello" # A placeholder default
}