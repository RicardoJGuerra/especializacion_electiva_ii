# Configurar el proveedor de AWS
provider "aws" {
  region = "us-east-1"
}

# Crear la tabla DynamoDB
resource "aws_dynamodb_table" "http_crud_table" {
  name         = "http-crud-tutorial-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Crear el rol IAM para Lambda
resource "aws_iam_role" "lambda_role" {
  name = "http-crud-tutorial-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Adjuntar políticas al rol IAM
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "dynamodb_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.http_crud_table.arn
      }
    ]
  })
}

# Crear el archivo ZIP para la función Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source {
    content  = <<EOF
import json
import boto3
from decimal import Decimal
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client('dynamodb')
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table('http-crud-tutorial-items')
tableName = 'http-crud-tutorial-items'

def lambda_handler(event, context):
    logger.info(f"Event: {json.dumps(event)}")
    body = {}
    statusCode = 200
    headers = {
        "Content-Type": "application/json"
    }
    try:
        # Intenta obtener routeKey del evento, o usa una combinación de httpMethod y resource
        route_key = event.get('routeKey')
        if not route_key:
            http_method = event.get('httpMethod')
            resource = event.get('resource')
            if http_method and resource:
                route_key = f"{http_method} {resource}"
            else:
                logger.error(f"Unable to determine route. Event structure: {json.dumps(event)}")
                raise ValueError("Unable to determine route from event")

        if route_key == "DELETE /items/{id}":
            table.delete_item(
                Key={'id': event['pathParameters']['id']})
            body = f"Deleted item {event['pathParameters']['id']}"
        elif route_key == "GET /items/{id}":
            response = table.get_item(
                Key={'id': event['pathParameters']['id']})
            item = response.get("Item")
            if item:
                body = [{'price': float(item['price']), 'id': item['id'], 'name': item['name']}]
            else:
                statusCode = 404
                body = "Item not found"
        elif route_key == "GET /items":
            response = table.scan()
            items = response.get("Items", [])
            body = []
            for item in items:
                body.append({'price': float(item['price']), 'id': item['id'], 'name': item['name']})
        elif route_key == "PUT /items":
            requestJSON = json.loads(event['body'])
            table.put_item(
                Item={
                    'id': requestJSON['id'],
                    'price': Decimal(str(requestJSON['price'])),
                    'name': requestJSON['name']
                })
            body = f"Put item {requestJSON['id']}"
        else:
            raise ValueError(f"Unsupported route: {route_key}")
    except KeyError as e:
        logger.error(f"KeyError: {str(e)}")
        statusCode = 400
        body = f"Bad request: {str(e)}"
    except ValueError as e:
        logger.error(f"ValueError: {str(e)}")
        statusCode = 400
        body = str(e)
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        statusCode = 500
        body = f"Unexpected error: {str(e)}"
    
    logger.info(f"Response: statusCode: {statusCode}, body: {body}")
    return {
        "statusCode": statusCode,
        "headers": headers,
        "body": json.dumps(body)
    }
EOF
    filename = "lambda_function.py"
  }
}

# Crear la función Lambda
resource "aws_lambda_function" "http_crud_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "http-crud-tutorial-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
}

# Crear API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "http-crud-tutorial-api"
  protocol_type = "HTTP"
}

# Crear la integración de API Gateway con Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"

  integration_uri    = aws_lambda_function.http_crud_function.invoke_arn
  integration_method = "POST"
}

# Crear las rutas para la API
resource "aws_apigatewayv2_route" "get_items" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_item" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "put_item" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "PUT /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "delete_item" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "DELETE /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Crear el stage para la API
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Permitir que API Gateway invoque la función Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.http_crud_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

# Output para la URL de invocación de la API
output "api_invoke_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
