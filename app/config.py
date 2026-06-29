import boto3
import json
import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    aws_region: str = "us-east-1"
    s3_bucket: str
    qdrant_host: str

    class Config:
        env_file = ".env"

settings = Settings()

# fetches API key from Secrets Manager
def get_secret(secret_name: str) -> str:
    client = boto3.client('secretsmanager', region_name=settings.aws_region)
    response = client.get_secret_value(SecretId=secret_name)
    secret = json.loads(response['SecretString'])
    return secret.get('GROQ_API_KEY') or response['SecretString']

# caches at startup
GROQ_API_KEY = get_secret('groq-api-key')