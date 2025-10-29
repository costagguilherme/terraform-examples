provider "aws" {
  region = "us-east-2"
}

# Cria uma role no IAM que a lambda irá usar
resource "aws_iam_role" "lambda_role" {
  name = "lambda_basic_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Faz a criação do lambda function com base no zip
resource "aws_lambda_function" "ufbank_lambda" {
  function_name = "ufbank_lambda"
  handler       = "lambda_function.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")
}

# Faz a criação do API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "ufbank_example"
  protocol_type = "HTTP"
}

# Associa a lambda ao API Gateway
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ufbank_lambda.arn
  payload_format_version = "2.0"
}

# Criando rota GET /
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Cria um "stage" da API Gateway, é como se fosse um ambiente da API (dev, hml , prd etc)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# Permissão da Lambda para API Gateway
# Sem essa permissão, a API Gateway até existe, mas não iria conseguiria executar a Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ufbank_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# Saída com o URL e endpoint da lambda
output "api_url" {
  value       = aws_apigatewayv2_stage.default.invoke_url
  description = "Endpoint HTTP da Lambda via API Gateway"
}