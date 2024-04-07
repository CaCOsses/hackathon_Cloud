import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TaskTable')

def lambda_handler(event, context):
    # Obtener todas las tareas de DynamoDB
    response = table.scan()
    tasks = response['Items']
    
    # Preparar la respuesta HTTP
    response = {
        "statusCode": 200,
        "body": json.dumps(tasks)
    }
    
    return response
