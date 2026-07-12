# Rapid Review AI: Event-Driven AI Document Pipeline for Legal Tech

> Automated contract analysis and question-answering using RAG (Retrieval-Augmented Generation) on AWS.

## Problem

Legal, insurance, and compliance teams spend hours manually reviewing contracts to answer simple questions. A paralegal at a mid-size firm reviews 30–50 contracts a week. At $80/hour, that is $6,000–$10,000/month in labour for work a properly architected system handles in seconds.

This project automates that workflow — PDFs are uploaded, processed asynchronously, and queried in natural language. Deployed on AWS with zero manual deployment steps.

---

## Architecture

![rapid-review AI Architecture](<./images/architecture main.png>)

### Architecture Summary

The system is split into three independent pipelines — **Ingestion**, **Query**, and **CI/CD** — connected by a shared VPC and Qdrant vector database.

**Ingestion Pipeline (Event-Driven, Asynchronous)**
1. A user uploads a PDF via the FastAPI `/upload` endpoint.
2. The PDF is stored in **S3**, which fires an object-created event.
3. An **S3 Event Notification** triggers a lightweight **Lambda (Trigger)** function.
4. The Trigger function pushes a message containing the S3 bucket and key into an **SQS Queue** (with a Dead Letter Queue for poison-pill messages).
5. A **Lambda Worker** (running as a container image for large ML dependencies) polls the SQS queue, receives the message, and:
   - Downloads the PDF from S3
   - Extracts text using `pypdf`
   - Chunks the text into 500-token segments with 50-token overlap
   - Generates 384-dimensional embeddings using `sentence-transformers/all-MiniLM-L6-v2`
   - Stores vectors and metadata in **Qdrant** (running on an EC2 instance in a private subnet)

**Query Pipeline (Synchronous, Always-On)**
1. A user sends a natural-language question to the FastAPI `/query` endpoint via an **Application Load Balancer (ALB)**.
2. The request is routed to **ECS Fargate** tasks running the FastAPI container.
3. The API embeds the question using the same `all-MiniLM-L6-v2` model.
4. It queries **Qdrant** for the top-k most relevant text chunks via vector similarity search.
5. The retrieved chunks are passed to **Groq (Llama 3 8B)** as context, and a synthesized answer is returned to the user.

**CI/CD & Deployment Pipeline**
1. A `git push` to the repository triggers **AWS CodePipeline**.
2. **CodeBuild** compiles the application, builds a Docker image, and pushes it to **ECR**.
3. CodePipeline then triggers a rolling deployment to **ECS Fargate**, ensuring zero-downtime updates with automatic rollback on health check failures.

**Security & Networking**
- **VPC** isolates the data plane: Qdrant lives in a private subnet with no direct internet access, reachable only via security group chaining from ECS and Lambda.
- **NAT Gateway** allows outbound internet access for ECS tasks and Lambda workers (to reach ECR, Groq, and model downloads) without exposing private resources to inbound traffic.
- **IAM roles** enforce least-privilege access at every layer — no hardcoded credentials.
- **AWS Secrets Manager** stores API keys (Groq, etc.) and is injected into ECS tasks at runtime.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| API Framework | FastAPI |
| Language | Python 3.12 |
| Vector DB | Qdrant |
| Embeddings | sentence-transformers (all-MiniLM-L6-v2) |
| LLM | Groq (Llama 3 8B) |
| Container | Docker |
| IaC | Terraform |
| Cloud | AWS |

---

## AWS Services

| Service | Purpose | Why It Was Chosen |
|---------|---------|-------------------|
| **S3** | Object storage for uploaded PDFs | Durable (99.999999999%), infinitely scalable, fractions of a cent per GB |
| **Lambda** | Event-driven trigger & async worker | Zero cost at rest, scale-to-zero compute, container images bypass 250MB limit |
| **SQS** | Decouple upload from processing | Absorbs load spikes, free retry logic + DLQ for poison-pill messages |
| **ECS Fargate** | Stateless query API | No EC2 management, pay per CPU/memory second |
| **EC2** | Qdrant vector database | Stateful workload requiring persistent storage, ~$15/month vs $700+ for managed alternatives |
| **ALB** | Load balancer for query API | Stable DNS endpoint, health checks, zero-downtime rolling deploys |
| **ECR** | Container image registry | AWS-native, integrates with CodePipeline |
| **CodePipeline + CodeBuild** | CI/CD | Git push → build → deploy with zero manual steps |
| **CloudWatch** | Logs, metrics, alarms | Production observability, custom query latency metrics |
| **Secrets Manager** | API key storage | No hardcoded credentials, least-privilege access |
| **VPC + IAM** | Networking & security | Private subnets for data plane, security group chaining, least-privilege roles |

---

## API Endpoints

### Upload a Document
```bash
curl -X POST http://localhost:8000/upload \
  -F "file=@sample-contract.pdf"
```

**Response:**
```json
{
  "message": "Upload successful",
  "s3_key": "uploads/sample-contract.pdf"
}
```

### Query a Document
```bash
curl -X POST http://ALB-DNS/query \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the payment terms?"}'
```

**Response:**
```json
{
  "answer": "The payment terms require Net 30 from the invoice date..."
}
```

### Health Check
```bash
curl http://localhost:8000/health
```

**Response:**
```json
{"status": "ok"}
```

---

## Local Development Setup

### Prerequisites

- Python 3.12+
- Docker
- AWS CLI configured
- Terraform (for Days 11–12)

### 1. Clone and Install

```bash
git clone <repo-url>
cd rapidReview AI

python -m venv doc-intel-venv
# On Windows:
doc-intel-venv\Scripts\activate
# On macOS/Linux:
source doc-intel-venv/bin/activate

pip install -r requirements.txt
```

### 2. Environment Variables

Create a `.env` file in the project root:

```env
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
S3_BUCKET=your-rapid-review-bucket
QDRANT_HOST=your-ec2-public-ip
GROQ_API_KEY=your_groq_key
```

### 3. Run FastAPI Locally

```bash
uvicorn app.main:app --reload
```

### 4. Build Worker Image Locally

```bash
cd lambda/worker
docker build -t rapid-review-worker .
```

---

## Cost Breakdown (Estimated Monthly)

| Component | Spec | Cost |
|-----------|------|------|
| EC2 (Qdrant) | t3.small | ~$15 |
| ECS Fargate (API) | 0.5 vCPU, 1 GB | ~$15 |
| ALB | Shared | ~$16 |
| NAT Gateway | 1x | ~$35 |
| S3 (100 GB stored) | Standard | ~$2.30 |
| SQS | Standard queue | ~$0 (free tier) |
| Lambda | 1M requests | ~$0 (free tier) |
| Secrets Manager | 1 secret | ~$0.40 |
| **Total** | | **~$70/month** |

---


## Article on Medium

[Checkout the article on Medium](https://medium.com/@kkrishnashivani18/automating-contract-review-event-driven-ai-document-pipeline-for-legal-tech-144bc1063eda)

---

## Key Design Decisions

### Why Qdrant on EC2 instead of OpenSearch Serverless?
OpenSearch Serverless has a minimum cost of ~$700/month. Qdrant on a `t3.small` is ~$15/month. For a portfolio project and startup demo, this trade-off is the right balance of capability and cost.

### Why Lambda (container image) for the worker instead of ECS Fargate?
The worker is event-driven — it only runs when documents are uploaded. Lambda scales to zero and costs nothing at rest. Fargate requires at least one always-running task. The container image approach bypasses Lambda's 250MB deployment package limit, allowing large ML libraries like `sentence-transformers`.

### Why SQS between upload and processing?
Decoupling. If 200 contracts are uploaded on a Monday morning, the queue absorbs the spike. The worker processes at its own pace. Nothing is lost. The Dead Letter Queue (DLQ) catches poison-pill messages after 3 retries.

### Why Groq instead of OpenAI?
Groq provides a generous free tier (14,400 requests/day on Llama 3 8B). OpenAI charges from the first token. For a portfolio project, free matters.

---

<!-- ## What I Would Add Next

- Auto-scaling on ECS based on ALB request count
- CloudFront CDN for the ALB
- Pre-signed URLs for direct-to-S3 uploads (bypassing the API server)
- Multi-AZ RDS for user accounts and metadata
- S3 lifecycle policies to move processed PDFs to Glacier after 90 days
- ReAct / Agentic RAG for multi-document reasoning and cross-referencing

---

## Resume Bullet

> Built an AI document review pipeline for contract analysis on AWS — event-driven ingestion via S3, Lambda, and SQS with a DLQ, vector search on Qdrant in a VPC-isolated private subnet, query API on ECS Fargate behind an ALB, automated CI/CD via CodePipeline with zero-downtime rolling deploys and CloudWatch rollback on health failures. Infrastructure defined in Terraform.

--- -->

## Repository Structure

```
rapidReview AI/
├── app/
│   ├── main.py              # FastAPI entrypoints: /upload, /query
│   ├── config.py            # Settings from env/Secrets Manager
│   └── __init__.py
├── lambda/
│   ├── trigger/
│   │   └── handler.py       # S3 event → SQS
│   └── worker/
│       ├── handler.py       # SQS consumer → process doc
│       ├── Dockerfile         # Lambda container image
│       └── requirements.txt # Worker dependencies
├── Dockerfile               # FastAPI container image
├── requirements.txt         # Root dependencies
├── infra/                   # Terraform files (Days 11–12)
├── buildspec.yml            # CodeBuild instructions
├── .env                     # Environment variables (not committed)
├── .gitignore
└── README.md                # This file
```

---

## License

MIT
