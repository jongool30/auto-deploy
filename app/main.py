from fastapi import FastAPI
from datetime import datetime
import os

app = FastAPI(title="Auto Deploy API", version="1.0.0")


@app.get("/")
def root():
    return {
        "service": "auto-deploy-api",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "timestamp": datetime.utcnow().isoformat(),
    }


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/info")
def info():
    return {
        "app": "auto-deploy-api",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "deployed_at": os.getenv("DEPLOYED_AT", "unknown"),
    }
