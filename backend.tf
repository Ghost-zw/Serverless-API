terraform {
  backend "s3" {
    bucket         = "my-tf-serverless-state"
    key            = "serverless-api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "serverless-tf-locks"
  }
}