from fastapi import FastAPI

app = FastAPI(title="python-api", version="0.1.0")


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/v1/hello")
def hello() -> dict[str, str]:
    return {
        "service": "python-api",
        "message": "hello from python-api",
    }
