import json
import boto3
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('messages-table')

def lambda_handler(event, context):
    body = json.loads(event['body'])

    message = body.get("message", "")
    message_id = str(uuid.uuid4())

    table.put_item(
        Item={
            "id": message_id
        }
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": "Saved successfully",
            "id": message_id
        })
    }
