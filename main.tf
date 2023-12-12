resource "aws_api_gateway_rest_api" "this" {
  name        = var.name
  description = var.description
  body        = var.body
}

resource "aws_vpc_endpoint" "this" {
  count             = var.vpc_endpoint == null ? 0 : 1
  vpc_id            = var.vpc_endpoint.vpc_id
  service_name      = "com.amazonaws.${var.vpc_endpoint.region}.execute-api"
  vpc_endpoint_type = var.vpc_endpoint.type
  subnet_ids        = var.vpc_endpoint.subnet_ids
}

resource "aws_api_gateway_rest_api_policy" "this" {
  count       = var.policy_statement == null ? 0 : 1
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [for s in var.policy_statement : {
      Resource  = [aws_api_gateway_rest_api.this.execution_arn]
      Principal = s.principal
      Action    = s.action
      Effect    = s.effect
      Condition = s.condition
    }]
  })
}

resource "aws_api_gateway_authorizer" "this" {
  for_each      = var.authorizers
  rest_api_id   = aws_api_gateway_rest_api.this.id
  name          = each.key
  type          = each.value.type
  provider_arns = each.value.provider_arns
}

module "domain_names" {
  source      = "ptonini/api-gateway-domain-name/aws"
  version     = "~> 1.0.0"
  for_each    = var.domain_names
  api_id      = aws_api_gateway_rest_api.this.id
  domain_name = each.key
  zone_id     = each.value.zone_id
  stage_name  = each.value.stage_name
}

module "deployments" {
  source      = "ptonini/api-gateway-deployment/aws"
  version     = "~> 1.0.0"
  for_each    = var.deployments
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers    = var.policy_statement == null ? each.value.triggers : merge(each.value.triggers, { policy = aws_api_gateway_rest_api_policy.this.policy })
  stages      = each.value.stages
}