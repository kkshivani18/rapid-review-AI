import json
import boto3
import os

sqs = boto3.client('sqs')
QUEUE_URL = os.environ['SQS_QUEUE_URL']

def handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        # safety check to process only PDFs 
        if not key.endswith('.pdf'):
            print(f"Skipping non-PDF file: {key}")
            continue

        message = {
            'bucket': bucket,
            'key': key
        }

        response = sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(message)
        )

        print(f"Queued {key} → message ID {response['MessageId']}")

    return {'statusCode': 200}