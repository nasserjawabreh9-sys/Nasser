from pydantic import BaseModel

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str

class ConfigStatus(BaseModel):
    openai_configured: bool
    github_configured: bool
    backend_version: str
