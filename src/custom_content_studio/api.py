from fastapi import FastAPI

app = FastAPI(title="Custom Content Studio")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
