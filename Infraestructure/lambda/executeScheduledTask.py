import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Crear un objeto en el bucket S3
    bucket_name = 'taskstorage'
    object_key = 'task.txt'
    s3.put_object(Bucket=bucket_name, Key=object_key, Body='Contenido de la tarea')

    # Preparar la respuesta HTTP
    response = {
        "statusCode": 200,
        "body": "Tarea ejecutada con éxito"
    }
    
    return response
