import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TaskTable')

def lambda_handler(event, context):
    # Obtener los datos del evento
    body = json.loads(event['body'])
    task_name = body['task_name']
    cron_expression = body['cron_expression']
    
    # Generar un ID único para la tarea
    task_id = str(hash(task_name + cron_expression))
    
    # Insertar la tarea en DynamoDB
    table.put_item(
        Item={
            'task_id': task_id,
            'task_name': task_name,
            'cron_expression': cron_expression
        }
    )

    # Preparar la respuesta HTTP
    response = {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Tarea creada con éxito",
            "task_id": task_id
        })
    }
    
    return response
