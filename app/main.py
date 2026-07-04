import uuid
import boto3
import time
from fastapi import FastAPI, File, UploadFile, HTTPException
from pydantic import BaseModel
from app.retrieval import answer_question
from app.config import settings

app = FastAPI(title="AI Docs Intelligence Pipeline")

# Initialize clients
s3 = boto3.client("s3", region_name=settings.aws_region)
cloudwatch = boto3.client('cloudwatch', region_name=settings.aws_region)

class QueryRequest(BaseModel):
    question: str

@app.post("/query")
async def query(req: QueryRequest):
    start = time.time()
    answer = answer_question(req.question)

    # calc latency
    latency_ms = (time.time() - start) * 1000

    cloudwatch.put_metric_data(
        Namespace='RapidReview/API',
        MetricData=[{
            'MetricName': 'QueryLatency',
            'Value': latency_ms,
            'Unit': 'Milliseconds'
        }]
    )

    return {"answer": answer, "latency_ms": round(latency_ms)}

@app.get("/health")
async def health():
    return {"status": "ok", "version": "1.0"}


@app.post("/upload")
async def upload(file: UploadFile = File(...)):
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=400, detail="Only PDF files are accepted.")

    # generate a unique key so uploads never collide
    key = f"uploads/{file.filename}"

    try:
        s3.upload_fileobj(file.file, settings.s3_bucket, key)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"S3 upload failed: {e}")

    return {"message": "Upload successful", "s3_key": key}