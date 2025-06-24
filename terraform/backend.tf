 terraform {
   backend "gcs" {
     bucket = "varun-verma-cwx-internal-tfstate-1750424602"
     prefix = "terraform/state"
   }
 }
