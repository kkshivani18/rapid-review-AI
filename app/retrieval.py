import os
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from groq import Groq

QDRANT_HOST = os.environ['QDRANT_HOST']
GROQ_API_KEY = os.environ['GROQ_API_KEY']
COLLECTION_NAME = "documents"

model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
qdrant = QdrantClient(host=QDRANT_HOST, port=6333)
groq_client = Groq(api_key=GROQ_API_KEY)


def answer_question(question: str) -> str:
    query_vector = model.encode(question).tolist()

    results = qdrant.query_points(
        collection_name=COLLECTION_NAME,
        query=query_vector,
        limit=5
    ).points

    context = "\n\n".join([r.payload['text'] for r in results])

    response = groq_client.chat.completions.create(
        model="llama-3.1-8b-instant", 
        messages=[
            {
                "role": "system",
                "content": "You are a legal document assistant. Answer questions based only on the provided contract text. Be precise and cite specific clauses when possible."
            },
            {
                "role": "user",
                "content": f"Context from contract:\n{context}\n\nQuestion: {question}"
            }
        ]
    )

    return response.choices[0].message.content