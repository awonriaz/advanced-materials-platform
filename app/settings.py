import os
from dataclasses import dataclass
from pathlib import Path


def _load_local_dotenv() -> None:
    """Load a local .env file for non-Docker development without printing secrets.

    Docker Compose and Kubernetes inject environment variables directly. This loader only
    helps when running `uvicorn` or scripts locally from the repository root.
    """
    env_path = Path(os.getenv("ENV_FILE", ".env"))
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def _required_secret(name: str) -> str:
    value = os.getenv(name, "").strip()
    blocked_values = {"change-this-demo-key", "your-api-key", "paste-your-api-key-here", "replace-me"}
    if not value or value.lower() in blocked_values:
        raise RuntimeError(
            f"Missing or unsafe placeholder value for required environment variable {name}. "
            "Create .env from .env.example for local runs, or inject the value through "
            "Docker Compose/Kubernetes/CI secrets."
        )
    return value


_load_local_dotenv()


@dataclass(frozen=True)
class Settings:
    app_name: str = os.getenv("APP_NAME", "Advanced Materials Supply Chain Platform")
    app_env: str = os.getenv("APP_ENV", "demo")
    api_key: str = _required_secret("API_KEY")
    db_path: str = os.getenv("DB_PATH", "./data/amscp.db")
    max_upload_mb: int = int(os.getenv("MAX_UPLOAD_MB", "8"))
    qc_fail_threshold: float = float(os.getenv("QC_FAIL_THRESHOLD", "32.0"))

    # Optional Level 6 integrations. The core API remains runnable on small machines
    # even when these services are not started.
    elasticsearch_url: str = os.getenv("ELASTICSEARCH_URL", "")
    elasticsearch_timeout_seconds: int = int(os.getenv("ELASTICSEARCH_TIMEOUT_SECONDS", "3"))
    search_index: str = os.getenv("SEARCH_INDEX", "material-passports")
    tensorflow_qc_url: str = os.getenv("TENSORFLOW_QC_URL", "")
    tensorflow_timeout_seconds: int = int(os.getenv("TENSORFLOW_TIMEOUT_SECONDS", "120"))
    mqtt_username: str = os.getenv("MQTT_USERNAME", "amscp_demo")
    mqtt_password: str = os.getenv("MQTT_PASSWORD", "")


settings = Settings()
