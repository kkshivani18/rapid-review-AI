import json
import boto3
import os
from pypdf import PdfReader
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.models import VectorParams, Distance, PointStruct
import io
import uuid

s3 = boto3.client('s3')
QDRANT_HOST = os.environ['QDRANT_HOST']
COLLECTION_NAME = "documents"
EMBEDDING_DIM = 384  # all-MiniLM-L6-v2 outputs 384-dimensional vectors

model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
qdrant = QdrantClient(host=QDRANT_HOST, port=6333)


def ensure_collection():
    collections = [c.name for c in qdrant.get_collections().collections]
    if COLLECTION_NAME not in collections:
        qdrant.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=EMBEDDING_DIM, distance=Distance.COSINE)
        )


def chunk_text(text, chunk_size=500, overlap=50):
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size - overlap):
        chunk = ' '.join(words[i:i + chunk_size])
        if chunk:
            chunks.append(chunk)
    return chunks


def handler(event, context):
    ensure_collection()

    for record in event['Records']:
        body = json.loads(record['body'])
        bucket = body['bucket']
        key = body['key']

        print(f"Processing: s3://{bucket}/{key}")

        # Fetch PDF from S3
        obj = s3.get_object(Bucket=bucket, Key=key)
        pdf_bytes = obj['Body'].read()

        # Extract text
        reader = PdfReader(io.BytesIO(pdf_bytes))
        full_text = ' '.join(page.extract_text() or '' for page in reader.pages)

        if not full_text.strip():
            print(f"Warning: no extractable text in {key}")
            return

        # Chunk and embed
        chunks = chunk_text(full_text)
        embeddings = model.encode(chunks).tolist()

        # Store in Qdrant
        points = [
            PointStruct(
                id=str(uuid.uuid4()),
                vector=embedding,
                payload={"text": chunk, "source": key}
            )
            for chunk, embedding in zip(chunks, embeddings)
        ]

        qdrant.upsert(collection_name=COLLECTION_NAME, points=points)
        print(f"Stored {len(points)} vectors for {key}")