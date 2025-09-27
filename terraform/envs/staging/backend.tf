terraform {
    backend "s3" {
        bucket = "prod-sahana-tf-bucket"
        key = "staging/terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "terraform-lock"
        encrypt = true
    }
}