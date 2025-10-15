# modules/webapp/variables.tf

variable "instance_count" {
  description = "Numero de instancias no Auto Scaling Group."
  type        = number
  default     = 1 # Valor Padrão
}

variable "db_password" {
  description = "Senha para o usuário master do banco de dados."
  type        = string
  sensitive   = true # Marcar como Secreto
}