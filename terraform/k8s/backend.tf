terraform {
  backend "s3" {
    bucket = "terraform-state-637423429740-us-east-1-an"
    key    = "hiive/k8s.tfstate"
    region = "us-east-1"
  }
}
