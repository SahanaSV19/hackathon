provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket" "tf_state"{
    bucket = "dev-sahana-tf-bucket"
    acl = "private"

    versioning {
        enabled = true
    }

    tags = {
        Name = "terraform-state"
        Purpose = "shared tf state"
}
}

resource "aws_s3_bucket_public_access_block" "block"{
    bucket = aws_s3_bucket.tf_state.id

    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}
resource "aws_dynamodb_table" "tf_locks" {
    name = "dev-sahana-tf-locks"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }

    tags = {
        Name = "terraform-locks"
        Purpose = "shared tf locks"
    }
}