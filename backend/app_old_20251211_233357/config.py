import os
from .schemas import ConfigStatus

def get_config_status() -> ConfigStatus:
    openai_key = os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    github_token = os.getenv("GITHUB_TOKEN")

    return ConfigStatus(
        openai_configured=bool(openai_key),
        github_configured=bool(github_token),
        backend_version="station-1.0",
    )

def get_openai_key() -> str:
    return os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY") or ""
