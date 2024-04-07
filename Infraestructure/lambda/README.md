
Las funciones son completamente funcionales y estan listas para desplegar.

Ejecutando `terraform apply` se despliegan todos los recurso solicitados para el ejercicio

En la sección de output nos aparecera la sección de la url dinamica que tendremos que sustituir para testear los diferentes endpoints de la api
Outputs:

rest_api_id = ${IDAPI}

ejecutando curl a los end points de listtask y createtask testearemos estas lambdas
` curl -X POST -H "Content-Type: application/json" -d '{"task_name": "CACO 2", "cron_expression": "0 0 * * ? *"}' http://localhost:4566/restapis/`${IDAPI}`/stage/_user_request_/createtask`
` curl http://localhost:4566/restapis/`${IDAPI}`/stage/_user_request_/listtask`

la lambda executeScheduleTask.py se ejecuta cada minuto y actualiza un bucket de S3 con un archivo de texto plano

Mejoras a futuro:
    Hacer que executeScheduledTask.py actualice las funciones si hiciera falta.
    Configurar mas mensajes de https (400, 500, etc) para tratar los diferentes eventos

## LAMBDAS
    1. createScheduledTask.py
    2. executeScheduledTask.py
    3. listScheduledTask.py