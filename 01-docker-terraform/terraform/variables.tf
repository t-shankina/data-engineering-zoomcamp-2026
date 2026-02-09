variable "gcp_credentials" {
  description = "GCP Credentials"
  default     = "../.secrets/gcp-key.json" # TODO set path to your json file with GCP Service Account key
}

variable "project" {
  description = "Project"
  default     = "sixth-hash-485519-d9"
}

variable "location" {
  description = "Location"
  default     = "US"
}
