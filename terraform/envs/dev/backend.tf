terraform{
    backend "s3" {
        bucket = "dev-sahana-tf-bucket"
        key = "dev/terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "dev-sahana-tf-locks"
        encrypt = true
    }
}