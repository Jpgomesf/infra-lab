variable "region" {
  description = "AWS region. us-east-1 is the cheapest and has the widest service coverage; it is also the noisiest region for outages."
  type        = string
  default     = "us-east-1"
}
