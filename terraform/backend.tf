terraform {
  backend "gcs" {
    bucket = "tf-state-bucket-arboreal-retina-466009-h1-unique" # <-- Use the bucket name you created
    prefix = "infra/state" # A sub-folder within the bucket for this specific state
  }
}