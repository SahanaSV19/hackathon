terraform {
    backend "s3" {
        bucket = "prod-sahana-tf-bucket"
        key = "prod/terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "terraform-lock"
        encrypt = true
    }
}