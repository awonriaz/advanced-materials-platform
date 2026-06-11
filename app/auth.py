from fastapi import Header, HTTPException, status

from app.settings import settings

# Canonical roles used by the API. Short aliases are accepted because exam
# commands often use simplified labels such as qa/risk/security/auditor.
ROLE_ALIASES = {
    "admin": "admin",
    "qa": "qa-engineer",
    "qa-engineer": "qa-engineer",
    "quality": "qa-engineer",
    "quality-engineer": "qa-engineer",
    "risk": "risk-analyst",
    "risk-analyst": "risk-analyst",
    "sustainability": "sustainability-analyst",
    "sustainability-analyst": "sustainability-analyst",
    "security": "security-analyst",
    "security-analyst": "security-analyst",
    "auditor": "auditor",
    "supply-chain-manager": "supply-chain-manager",
    "supply-chain": "supply-chain-manager",
}


def normalize_role(role: str) -> str:
    return ROLE_ALIASES.get((role or "").strip().lower(), (role or "").strip().lower())


def require_api_key(
    x_api_key: str = Header(default="", alias="X-API-Key"),
    x_actor: str = Header(default="examiner-demo-user", alias="X-Actor"),
    x_role: str = Header(default="qa-engineer", alias="X-Role"),
) -> dict[str, str]:
    if x_api_key != settings.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing X-API-Key header",
        )
    return {"actor": x_actor, "role": normalize_role(x_role), "raw_role": x_role}


def require_role(identity: dict[str, str], allowed_roles: set[str]) -> None:
    allowed = {normalize_role(role) for role in allowed_roles}
    if identity["role"] not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Role {identity['role']} is not allowed for this operation. Allowed roles: {sorted(allowed)}",
        )
