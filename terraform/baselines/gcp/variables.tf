variable "gcp_project" {
  description = "GCP project ID to deploy the baseline services into"
  type        = string
  default     = "cge-p-capstone"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the WIF service account, as OWNER/REPO"
  type        = string
  default     = "Larry-Wilkes-CyberCloud/cge-p-capstone"
}
