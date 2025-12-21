"""
Authentication middleware and dependencies for JWT validation
"""
from fastapi import Header, HTTPException, status
from typing import Optional
from core.utils import verify_token


async def get_current_user(authorization: Optional[str] = Header(None, alias="Authorization")) -> dict:
    """
    Dependency to get current user from JWT token.
    Validates the token and returns the user payload.
    
    Usage:
        @router.get("/protected")
        async def protected_route(current_user: dict = Depends(get_current_user)):
            user_id = current_user["sub"]
            user_type = current_user["user_type"]
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if it's a Bearer token
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format. Use: Bearer <token>",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = parts[1]
    
    # Verify token
    payload = verify_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return payload


async def get_current_merchant(current_user: Optional[dict] = None) -> dict:
    """
    Dependency to ensure current user is a merchant.
    Use after get_current_user.
    """
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    
    if current_user.get("user_type") != "merchant":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is only accessible to merchants",
        )
    
    return current_user


async def get_current_user_account(current_user: Optional[dict] = None) -> dict:
    """
    Dependency to ensure current user is a regular user (not merchant).
    Use after get_current_user.
    """
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )
    
    if current_user.get("user_type") != "user":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This endpoint is only accessible to users",
        )
    
    return current_user


def verify_resource_ownership(current_user: dict, resource_id: str) -> bool:
    """
    Verify that the current user owns the resource they're trying to access.
    Returns True if user owns the resource, raises HTTPException otherwise.
    """
    user_id = current_user.get("sub")
    
    if user_id != resource_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access this resource",
        )
    
    return True
