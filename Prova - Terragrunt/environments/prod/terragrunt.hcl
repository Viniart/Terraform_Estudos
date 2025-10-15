# Configura o local onde o estado será guardado
remote_state {
  backend = "s3"
  config = {
    bucket         = "bucket-teste-terragrunt-vini" # Use o nome do bucket criado no passo anterior
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
terraform {
  source = "../../modules/webapp"
}

# Define as "respostas" para as perguntas do nosso módulo, específicas para DEV
inputs = {
  instance_count = 2
  db_password    = "senai123"
}