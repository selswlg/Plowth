"""
Authentication API endpoints: register, login, refresh, guest, upgrade, profile.
"""

import uuid as uuid_mod

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User, Subscription, LearningProfile
from app.schemas import (
    UserRegister, UserLogin, TokenResponse, TokenRefresh, UserResponse,
    GuestRequest, GuestUpgradeRequest,
)
from app.services.auth_service import (
    create_user, authenticate_user, get_user_by_email,
    create_access_token, create_refresh_token, decode_token,
    hash_password,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(body: UserRegister, db: AsyncSession = Depends(get_db)):
    """Register a new user account."""
    existing = await get_user_by_email(db, body.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    user = await create_user(db, email=body.email, password=body.password, name=body.name)

    # Create default subscription (free tier)
    subscription = Subscription(user_id=user.id, plan="free")
    db.add(subscription)

    # Create empty learning profile
    profile = LearningProfile(user_id=user.id)
    db.add(profile)

    await db.flush()

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/login", response_model=TokenResponse)
async def login(body: UserLogin, db: AsyncSession = Depends(get_db)):
    """Authenticate user and return tokens."""
    user = await authenticate_user(db, body.email, body.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/guest", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def guest_login(body: GuestRequest, db: AsyncSession = Depends(get_db)):
    """Create a guest session. No email/password required.
    Guest data lives locally on the client; this just provides a server-side
    user record for optional future upgrade.
    """
    # Check if this device already has a guest account
    result = await db.execute(
        select(User).where(User.device_id == body.device_id, User.is_guest == True)
    )
    existing_guest = result.scalar_one_or_none()

    if existing_guest:
        # Return tokens for existing guest
        return TokenResponse(
            access_token=create_access_token(existing_guest.id),
            refresh_token=create_refresh_token(existing_guest.id),
        )

    # Create new guest user
    guest = User(
        is_guest=True,
        auth_provider="guest",
        device_id=body.device_id,
        preferences={"learning_goal": body.learning_goal} if body.learning_goal else {},
    )
    db.add(guest)
    await db.flush()

    return TokenResponse(
        access_token=create_access_token(guest.id),
        refresh_token=create_refresh_token(guest.id),
    )


@router.post("/upgrade", response_model=TokenResponse)
async def upgrade_guest(
    body: GuestUpgradeRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upgrade a guest account to a full registered account.
    Associates email/password with the existing guest user record,
    preserving all local data that gets synced afterward.
    """
    if not current_user.is_guest:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account is already registered",
        )

    # Check email availability
    existing = await get_user_by_email(db, body.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    # Upgrade guest → registered
    current_user.email = body.email
    current_user.hashed_password = hash_password(body.password)
    current_user.name = body.name
    current_user.is_guest = False
    current_user.auth_provider = "email"

    # Create subscription & profile if not exist
    if not current_user.subscription:
        db.add(Subscription(user_id=current_user.id, plan="free"))
    if not current_user.learning_profile:
        db.add(LearningProfile(user_id=current_user.id))

    await db.flush()

    return TokenResponse(
        access_token=create_access_token(current_user.id),
        refresh_token=create_refresh_token(current_user.id),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(body: TokenRefresh, db: AsyncSession = Depends(get_db)):
    """Refresh an access token using a valid refresh token."""
    payload = decode_token(body.refresh_token)
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    user_id = uuid_mod.UUID(payload["sub"])

    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
    )


@router.get("/me", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_user)):
    """Get current user's profile."""
    return current_user

