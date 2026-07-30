from dotenv import load_dotenv
from pathlib import Path

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

import os
import logging
import uuid
import bcrypt
import jwt
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Annotated
from bson import ObjectId

from fastapi import FastAPI, APIRouter, HTTPException, Depends, Request, Response, UploadFile, File, Form, Header, Query
from starlette.middleware.cors import CORSMiddleware
from starlette.responses import StreamingResponse
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, Field, EmailStr, BeforeValidator, ConfigDict

from storage import init_storage, put_object, get_object, APP_NAME


# ----- Mongo setup -----
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# ----- JWT config -----
JWT_ALGORITHM = "HS256"

def get_jwt_secret() -> str:
    return os.environ["JWT_SECRET"]

def hash_password(pw: str) -> str:
    return bcrypt.hashpw(pw.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False

def create_access_token(user_id: str, email: str) -> str:
    payload = {
        "sub": user_id,
        "email": email,
        "exp": datetime.now(timezone.utc) + timedelta(days=7),
        "type": "access",
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm=JWT_ALGORITHM)


# ----- Models -----
class UserPublic(BaseModel):
    id: str
    email: EmailStr
    name: str
    avatar_url: Optional[str] = None
    role: str = "user"
    xp: int = 0
    level: int = 1
    streak_days: int = 0
    badges: List[str] = []
    completed_quests: List[str] = []
    created_at: Optional[str] = None


class RegisterInput(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    name: str = Field(min_length=1, max_length=50)


class LoginInput(BaseModel):
    email: EmailStr
    password: str


class Quest(BaseModel):
    id: str
    title: str
    description: str
    location: str
    location_id: str
    xp_reward: int
    difficulty: str  # easy | medium | hard
    category: str    # fitness | exploration | social | academic
    duration_min: int
    icon: str


class QuestCompleteInput(BaseModel):
    quest_id: str


# ----- Auth helpers -----
def _xp_to_level(xp: int) -> int:
    # simple curve: level = 1 + floor(sqrt(xp / 100))
    import math
    return 1 + int(math.floor(math.sqrt(max(0, xp) / 100)))


def _serialize_user(doc: dict) -> dict:
    return {
        "id": str(doc["_id"]),
        "email": doc["email"],
        "name": doc.get("name", ""),
        "avatar_url": doc.get("avatar_url"),
        "role": doc.get("role", "user"),
        "xp": doc.get("xp", 0),
        "level": doc.get("level", 1),
        "streak_days": doc.get("streak_days", 0),
        "badges": doc.get("badges", []),
        "completed_quests": doc.get("completed_quests", []),
        "created_at": doc.get("created_at"),
    }


async def get_current_user(request: Request) -> dict:
    token = request.cookies.get("access_token")
    if not token:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        payload = jwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user = await db.users.find_one({"_id": ObjectId(payload["sub"])})
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def _set_auth_cookie(response: Response, token: str):
    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,
        secure=True,
        samesite="none",
        max_age=60 * 60 * 24 * 7,
        path="/",
    )


# ----- FastAPI app -----
app = FastAPI(title="VIT Quest API")
api_router = APIRouter(prefix="/api")


# ----- Auth routes -----
@api_router.post("/auth/register")
async def register(payload: RegisterInput, response: Response):
    email = payload.email.lower()
    existing = await db.users.find_one({"email": email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    doc = {
        "email": email,
        "password_hash": hash_password(payload.password),
        "name": payload.name,
        "role": "user",
        "avatar_url": f"https://api.dicebear.com/7.x/adventurer/svg?seed={email}",
        "xp": 0,
        "level": 1,
        "streak_days": 1,
        "badges": [],
        "completed_quests": [],
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    result = await db.users.insert_one(doc)
    doc["_id"] = result.inserted_id
    token = create_access_token(str(result.inserted_id), email)
    _set_auth_cookie(response, token)
    return {"user": _serialize_user(doc), "token": token}


@api_router.post("/auth/login")
async def login(payload: LoginInput, response: Response):
    email = payload.email.lower()
    user = await db.users.find_one({"email": email})
    if not user or not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    token = create_access_token(str(user["_id"]), email)
    _set_auth_cookie(response, token)
    return {"user": _serialize_user(user), "token": token}


@api_router.post("/auth/logout")
async def logout(response: Response):
    response.delete_cookie("access_token", path="/")
    return {"ok": True}


@api_router.get("/auth/me")
async def me(user: dict = Depends(get_current_user)):
    return _serialize_user(user)


# ----- Quest routes -----
@api_router.get("/quests")
async def list_quests(user: dict = Depends(get_current_user)):
    quests = await db.quests.find({}, {"_id": 0}).to_list(200)
    completed = set(user.get("completed_quests", []))
    for q in quests:
        q["completed"] = q["id"] in completed
    return quests


@api_router.get("/quests/active")
async def active_quests(user: dict = Depends(get_current_user)):
    """Quests not yet completed by user, limited to 6"""
    completed = set(user.get("completed_quests", []))
    quests = await db.quests.find({}, {"_id": 0}).to_list(200)
    active = [q for q in quests if q["id"] not in completed][:6]
    for q in active:
        q["completed"] = False
    return active


@api_router.post("/quests/complete")
async def complete_quest(payload: QuestCompleteInput, user: dict = Depends(get_current_user)):
    quest = await db.quests.find_one({"id": payload.quest_id}, {"_id": 0})
    if not quest:
        raise HTTPException(status_code=404, detail="Quest not found")
    if payload.quest_id in user.get("completed_quests", []):
        raise HTTPException(status_code=400, detail="Quest already completed")

    new_xp = user.get("xp", 0) + quest["xp_reward"]
    new_level = _xp_to_level(new_xp)
    completed_quests = user.get("completed_quests", []) + [payload.quest_id]
    badges = list(user.get("badges", []))

    # Badge unlocks
    if len(completed_quests) == 1 and "first-quest" not in badges:
        badges.append("first-quest")
    if len(completed_quests) >= 5 and "explorer" not in badges:
        badges.append("explorer")
    if new_level >= 5 and "veteran" not in badges:
        badges.append("veteran")
    if quest["category"] == "fitness" and "fit-warrior" not in badges:
        # unlock after any fitness quest
        badges.append("fit-warrior")

    await db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {
            "xp": new_xp,
            "level": new_level,
            "completed_quests": completed_quests,
            "badges": badges,
        }},
    )
    updated = await db.users.find_one({"_id": user["_id"]})
    return {
        "user": _serialize_user(updated),
        "xp_gained": quest["xp_reward"],
        "leveled_up": new_level > user.get("level", 1),
        "new_badges": [b for b in badges if b not in user.get("badges", [])],
    }


# ----- Leaderboard -----
@api_router.get("/leaderboard")
async def leaderboard(scope: str = "all", user: dict = Depends(get_current_user)):
    docs = await db.users.find(
        {},
        {"password_hash": 0}
    ).sort("xp", -1).limit(50).to_list(50)
    result = []
    for i, d in enumerate(docs):
        result.append({
            "rank": i + 1,
            "id": str(d["_id"]),
            "name": d.get("name", ""),
            "avatar_url": d.get("avatar_url"),
            "xp": d.get("xp", 0),
            "level": d.get("level", 1),
            "is_you": str(d["_id"]) == str(user["_id"]),
        })
    return result


# ----- Locations (campus points of interest) -----
@api_router.get("/locations")
async def list_locations(user: dict = Depends(get_current_user)):
    locs = await db.locations.find({}, {"_id": 0}).to_list(200)
    return locs


# ----- Root -----
@api_router.get("/")
async def root():
    return {"message": "VIT Quest API", "status": "online"}


# ----- File uploads -----
MAX_UPLOAD_BYTES = 20 * 1024 * 1024  # 20 MB
ALLOWED_IMAGE = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_VIDEO = {"video/mp4", "video/quicktime", "video/webm"}
EXT_FROM_MIME = {
    "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif",
    "video/mp4": "mp4", "video/quicktime": "mov", "video/webm": "webm",
}


def _upload_to_dict(doc: dict, backend_prefix: str = "") -> dict:
    return {
        "id": doc["id"],
        "kind": doc.get("kind"),
        "quest_id": doc.get("quest_id"),
        "owner_id": doc.get("owner_id"),
        "owner_name": doc.get("owner_name"),
        "owner_avatar": doc.get("owner_avatar"),
        "content_type": doc.get("content_type"),
        "is_public": doc.get("is_public", False),
        "created_at": doc.get("created_at"),
        "caption": doc.get("caption"),
        "url": f"{backend_prefix}/api/uploads/{doc['id']}/file",
    }


async def _store_upload(
    *,
    user: dict,
    file: UploadFile,
    kind: str,  # "avatar" | "quest_proof"
    quest_id: Optional[str] = None,
    caption: Optional[str] = None,
    is_public: bool = False,
) -> dict:
    content_type = (file.content_type or "").lower()
    if kind == "avatar":
        if content_type not in ALLOWED_IMAGE:
            raise HTTPException(status_code=400, detail="Avatar must be an image (jpg/png/webp/gif)")
    else:
        if content_type not in (ALLOWED_IMAGE | ALLOWED_VIDEO):
            raise HTTPException(status_code=400, detail="Only images and short videos are allowed")

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds 20 MB limit")

    ext = EXT_FROM_MIME.get(content_type, "bin")
    file_id = str(uuid.uuid4())
    storage_path = f"{APP_NAME}/uploads/{user['_id']}/{file_id}.{ext}"

    try:
        result = put_object(storage_path, data, content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Storage upload failed: {e}")

    doc = {
        "id": file_id,
        "kind": kind,
        "quest_id": quest_id,
        "owner_id": str(user["_id"]),
        "owner_name": user.get("name"),
        "owner_avatar": user.get("avatar_url"),
        "storage_path": result.get("path", storage_path),
        "content_type": content_type,
        "size": result.get("size", len(data)),
        "is_public": bool(is_public),
        "is_deleted": False,
        "caption": caption,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    await db.uploads.insert_one(doc)
    return doc


@api_router.post("/uploads/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
):
    doc = await _store_upload(user=user, file=file, kind="avatar", is_public=True)
    # Point user's avatar_url at this new upload
    new_url = f"/api/uploads/{doc['id']}/file"
    await db.users.update_one({"_id": user["_id"]}, {"$set": {"avatar_url": new_url}})
    return {"upload": _upload_to_dict(doc), "avatar_url": new_url}


@api_router.post("/uploads/quest-proof")
async def upload_quest_proof(
    quest_id: str = Form(...),
    caption: Optional[str] = Form(None),
    is_public: bool = Form(False),
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
):
    quest = await db.quests.find_one({"id": quest_id}, {"_id": 0})
    if not quest:
        raise HTTPException(status_code=404, detail="Quest not found")

    doc = await _store_upload(
        user=user, file=file, kind="quest_proof",
        quest_id=quest_id, caption=caption, is_public=is_public,
    )
    # Mark quest complete (idempotent) and award XP if new
    xp_gained = 0
    leveled_up = False
    new_badges: List[str] = []
    if quest_id not in user.get("completed_quests", []):
        new_xp = user.get("xp", 0) + quest["xp_reward"]
        new_level = _xp_to_level(new_xp)
        completed = user.get("completed_quests", []) + [quest_id]
        badges = list(user.get("badges", []))
        if len(completed) == 1 and "first-quest" not in badges:
            badges.append("first-quest")
        if len(completed) >= 5 and "explorer" not in badges:
            badges.append("explorer")
        if new_level >= 5 and "veteran" not in badges:
            badges.append("veteran")
        if quest["category"] == "fitness" and "fit-warrior" not in badges:
            badges.append("fit-warrior")
        await db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {"xp": new_xp, "level": new_level,
                      "completed_quests": completed, "badges": badges}},
        )
        xp_gained = quest["xp_reward"]
        leveled_up = new_level > user.get("level", 1)
        new_badges = [b for b in badges if b not in user.get("badges", [])]

    updated_user = await db.users.find_one({"_id": user["_id"]})
    return {
        "upload": _upload_to_dict(doc),
        "user": _serialize_user(updated_user),
        "xp_gained": xp_gained,
        "leveled_up": leveled_up,
        "new_badges": new_badges,
    }


@api_router.get("/uploads/{file_id}/file")
async def download_upload(
    file_id: str,
    auth: Optional[str] = Query(None),
    authorization: Optional[str] = Header(None),
):
    """Stream a stored file. Public uploads are open to anyone; private uploads
    require a valid access token via `?auth=<jwt>` or `Authorization: Bearer`."""
    doc = await db.uploads.find_one({"id": file_id, "is_deleted": False})
    if not doc:
        raise HTTPException(status_code=404, detail="File not found")

    if not doc.get("is_public"):
        token = None
        if authorization and authorization.startswith("Bearer "):
            token = authorization[7:]
        elif auth:
            token = auth
        if not token:
            raise HTTPException(status_code=401, detail="Auth required")
        try:
            payload = jwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGORITHM])
            requester_id = payload.get("sub")
        except jwt.PyJWTError:
            raise HTTPException(status_code=401, detail="Invalid token")
        if requester_id != doc["owner_id"]:
            # Only owner (or admin) can view private files
            requester = await db.users.find_one({"_id": ObjectId(requester_id)}) if requester_id else None
            if not requester or requester.get("role") != "admin":
                raise HTTPException(status_code=403, detail="Forbidden")

    try:
        data, ctype = get_object(doc["storage_path"])
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Storage read failed: {e}")

    return Response(content=data, media_type=doc.get("content_type") or ctype)


@api_router.get("/uploads/mine")
async def list_my_uploads(user: dict = Depends(get_current_user)):
    docs = await db.uploads.find(
        {"owner_id": str(user["_id"]), "is_deleted": False}
    ).sort("created_at", -1).limit(50).to_list(50)
    return [_upload_to_dict(d) for d in docs]


@api_router.put("/uploads/{file_id}/visibility")
async def toggle_visibility(
    file_id: str,
    is_public: bool = Query(...),
    user: dict = Depends(get_current_user),
):
    doc = await db.uploads.find_one({"id": file_id, "is_deleted": False})
    if not doc:
        raise HTTPException(status_code=404, detail="File not found")
    if doc["owner_id"] != str(user["_id"]):
        raise HTTPException(status_code=403, detail="Not your upload")
    await db.uploads.update_one({"id": file_id}, {"$set": {"is_public": bool(is_public)}})
    doc["is_public"] = bool(is_public)
    return _upload_to_dict(doc)


@api_router.delete("/uploads/{file_id}")
async def delete_upload(file_id: str, user: dict = Depends(get_current_user)):
    doc = await db.uploads.find_one({"id": file_id, "is_deleted": False})
    if not doc:
        raise HTTPException(status_code=404, detail="File not found")
    if doc["owner_id"] != str(user["_id"]) and user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Not your upload")
    await db.uploads.update_one({"id": file_id}, {"$set": {"is_deleted": True}})
    return {"ok": True}


@api_router.get("/feed")
async def public_feed(user: dict = Depends(get_current_user), limit: int = 30):
    docs = await db.uploads.find(
        {"is_public": True, "is_deleted": False, "kind": "quest_proof"}
    ).sort("created_at", -1).limit(min(limit, 50)).to_list(limit)
    # Attach quest info
    quest_ids = list({d["quest_id"] for d in docs if d.get("quest_id")})
    quests = {q["id"]: q for q in await db.quests.find({"id": {"$in": quest_ids}}, {"_id": 0}).to_list(200)}
    result = []
    for d in docs:
        item = _upload_to_dict(d)
        q = quests.get(d.get("quest_id"))
        if q:
            item["quest_title"] = q["title"]
            item["quest_location"] = q["location"]
            item["quest_xp"] = q["xp_reward"]
        result.append(item)
    return result


# ============================================================================
# Friend requests, nearby users, groups, VTOP timetable
# ============================================================================
import math


class LocationPing(BaseModel):
    lat: float
    lng: float


class FriendRequestInput(BaseModel):
    to_user_id: str


def _haversine_m(lat1, lng1, lat2, lng2) -> float:
    R = 6371000.0
    p1 = math.radians(lat1); p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1); dl = math.radians(lng2 - lng1)
    a = math.sin(dp/2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl/2) ** 2
    return R * 2 * math.asin(math.sqrt(a))


def _public_user(doc: dict, *, me_id: str, friend_ids: set, pending_out: set, pending_in: set) -> dict:
    uid = str(doc["_id"])
    status = "self"
    if uid != me_id:
        if uid in friend_ids:
            status = "friends"
        elif uid in pending_out:
            status = "requested"
        elif uid in pending_in:
            status = "incoming"
        else:
            status = "none"
    return {
        "id": uid,
        "name": doc.get("name"),
        "avatar_url": doc.get("avatar_url"),
        "xp": doc.get("xp", 0),
        "level": doc.get("level", 1),
        "friend_status": status,
    }


async def _my_friend_context(user: dict):
    me_id = str(user["_id"])
    friend_ids = set(user.get("friend_ids", []))
    outgoing = await db.friend_requests.find(
        {"from_user_id": me_id, "status": "pending"}
    ).to_list(200)
    incoming = await db.friend_requests.find(
        {"to_user_id": me_id, "status": "pending"}
    ).to_list(200)
    return me_id, friend_ids, {r["to_user_id"] for r in outgoing}, {r["from_user_id"] for r in incoming}


@api_router.put("/users/location")
async def update_my_location(payload: LocationPing, user: dict = Depends(get_current_user)):
    await db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {
            "location": {"lat": payload.lat, "lng": payload.lng},
            "location_updated_at": datetime.now(timezone.utc).isoformat(),
        }},
    )
    return {"ok": True}


@api_router.get("/users/nearby")
async def nearby_users(radius_m: float = 50, user: dict = Depends(get_current_user)):
    loc = user.get("location")
    if not loc:
        return []
    me_id, friend_ids, pending_out, pending_in = await _my_friend_context(user)
    cutoff = (datetime.now(timezone.utc) - timedelta(minutes=30)).isoformat()
    candidates = await db.users.find(
        {"_id": {"$ne": user["_id"]},
         "location": {"$exists": True},
         "location_updated_at": {"$gte": cutoff}},
        {"password_hash": 0}
    ).to_list(200)
    result = []
    for c in candidates:
        cl = c.get("location") or {}
        try:
            d = _haversine_m(loc["lat"], loc["lng"], cl["lat"], cl["lng"])
        except Exception:
            continue
        if d <= radius_m:
            item = _public_user(c, me_id=me_id, friend_ids=friend_ids,
                                pending_out=pending_out, pending_in=pending_in)
            item["distance_m"] = round(d, 1)
            result.append(item)
    result.sort(key=lambda x: x["distance_m"])
    return result


@api_router.post("/friends/requests")
async def send_friend_request(payload: FriendRequestInput, user: dict = Depends(get_current_user)):
    me_id = str(user["_id"])
    if payload.to_user_id == me_id:
        raise HTTPException(status_code=400, detail="Cannot friend yourself")
    target = await db.users.find_one({"_id": ObjectId(payload.to_user_id)})
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    if payload.to_user_id in user.get("friend_ids", []):
        raise HTTPException(status_code=400, detail="Already friends")
    existing = await db.friend_requests.find_one({
        "from_user_id": me_id, "to_user_id": payload.to_user_id, "status": "pending"
    })
    if existing:
        raise HTTPException(status_code=400, detail="Request already sent")
    # If they already sent us one, auto-accept
    reverse = await db.friend_requests.find_one({
        "from_user_id": payload.to_user_id, "to_user_id": me_id, "status": "pending"
    })
    if reverse:
        await db.friend_requests.update_one({"_id": reverse["_id"]}, {"$set": {"status": "accepted"}})
        await db.users.update_one({"_id": user["_id"]}, {"$addToSet": {"friend_ids": payload.to_user_id}})
        await db.users.update_one({"_id": target["_id"]}, {"$addToSet": {"friend_ids": me_id}})
        return {"status": "accepted"}
    req_id = str(uuid.uuid4())
    await db.friend_requests.insert_one({
        "id": req_id, "from_user_id": me_id, "to_user_id": payload.to_user_id,
        "status": "pending", "created_at": datetime.now(timezone.utc).isoformat(),
    })
    return {"status": "pending", "id": req_id}


@api_router.get("/friends/requests")
async def list_friend_requests(user: dict = Depends(get_current_user)):
    me_id = str(user["_id"])
    incoming = await db.friend_requests.find(
        {"to_user_id": me_id, "status": "pending"}
    ).sort("created_at", -1).to_list(50)
    ids = [ObjectId(r["from_user_id"]) for r in incoming]
    users = {str(u["_id"]): u for u in await db.users.find({"_id": {"$in": ids}}).to_list(200)}
    return [{
        "id": r["id"],
        "from": {
            "id": r["from_user_id"],
            "name": users.get(r["from_user_id"], {}).get("name"),
            "avatar_url": users.get(r["from_user_id"], {}).get("avatar_url"),
            "level": users.get(r["from_user_id"], {}).get("level", 1),
        },
        "created_at": r["created_at"],
    } for r in incoming]


@api_router.post("/friends/requests/{req_id}/accept")
async def accept_friend_request(req_id: str, user: dict = Depends(get_current_user)):
    me_id = str(user["_id"])
    req = await db.friend_requests.find_one({"id": req_id, "to_user_id": me_id, "status": "pending"})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    await db.friend_requests.update_one({"id": req_id}, {"$set": {"status": "accepted"}})
    await db.users.update_one({"_id": user["_id"]}, {"$addToSet": {"friend_ids": req["from_user_id"]}})
    await db.users.update_one({"_id": ObjectId(req["from_user_id"])}, {"$addToSet": {"friend_ids": me_id}})
    return {"ok": True}


@api_router.post("/friends/requests/{req_id}/decline")
async def decline_friend_request(req_id: str, user: dict = Depends(get_current_user)):
    await db.friend_requests.update_one(
        {"id": req_id, "to_user_id": str(user["_id"])},
        {"$set": {"status": "declined"}},
    )
    return {"ok": True}


@api_router.get("/friends")
async def list_friends(user: dict = Depends(get_current_user)):
    ids = [ObjectId(fid) for fid in user.get("friend_ids", [])]
    if not ids:
        return []
    docs = await db.users.find({"_id": {"$in": ids}}, {"password_hash": 0}).to_list(200)
    me_id, friend_ids, po, pi = await _my_friend_context(user)
    return [_public_user(d, me_id=me_id, friend_ids=friend_ids, pending_out=po, pending_in=pi) for d in docs]


# ----- Groups -----
SEED_GROUPS = [
    {"id": "g-ab1-study",  "name": "AB-1 Study Squad",  "description": "Study jams for AB-1 courses. Meets Wed 6 PM at the Central Library.", "color": "#00E5FF", "icon": "BookOpen"},
    {"id": "g-hackathon",  "name": "Hackathon Prep",    "description": "Weekly idea drops + team-forming for SIH and campus hackathons.",     "color": "#C084FC", "icon": "Rocket"},
    {"id": "g-fit-squad",  "name": "Fit Squad",         "description": "Daily 6 AM runs around the Cricket Ground. All fitness levels.",       "color": "#39FF14", "icon": "Dumbbell"},
]


@api_router.get("/groups")
async def list_groups(user: dict = Depends(get_current_user)):
    docs = await db.groups.find({}, {"_id": 0}).to_list(200)
    me_id = str(user["_id"])
    return [{**g, "member_count": len(g.get("member_ids", [])), "joined": me_id in g.get("member_ids", [])} for g in docs]


@api_router.post("/groups/{group_id}/join")
async def join_group(group_id: str, user: dict = Depends(get_current_user)):
    me_id = str(user["_id"])
    g = await db.groups.find_one({"id": group_id})
    if not g:
        raise HTTPException(status_code=404, detail="Group not found")
    await db.groups.update_one({"id": group_id}, {"$addToSet": {"member_ids": me_id}})
    return {"ok": True, "joined": True}


@api_router.post("/groups/{group_id}/leave")
async def leave_group(group_id: str, user: dict = Depends(get_current_user)):
    await db.groups.update_one({"id": group_id}, {"$pull": {"member_ids": str(user["_id"])}})
    return {"ok": True, "joined": False}


# ----- VTOP timetable upload -----
ALLOWED_TIMETABLE = {"application/pdf", "image/jpeg", "image/png", "image/webp",
                     "text/calendar", "text/plain",
                     "application/vnd.ms-excel",
                     "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}


@api_router.post("/timetable/upload")
async def upload_timetable(
    file: UploadFile = File(...),
    user: dict = Depends(get_current_user),
):
    content_type = (file.content_type or "").lower()
    if content_type not in ALLOWED_TIMETABLE and not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only PDF, image, ICS, or Excel timetables are accepted")

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds 20 MB limit")

    ext = (file.filename or "file").split(".")[-1].lower() if "." in (file.filename or "") else "bin"
    file_id = str(uuid.uuid4())
    storage_path = f"{APP_NAME}/timetables/{user['_id']}/{file_id}.{ext}"
    try:
        put_object(storage_path, data, content_type or "application/octet-stream")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Storage upload failed: {e}")

    doc = {
        "id": file_id,
        "kind": "timetable",
        "owner_id": str(user["_id"]),
        "owner_name": user.get("name"),
        "owner_avatar": user.get("avatar_url"),
        "storage_path": storage_path,
        "content_type": content_type or "application/octet-stream",
        "size": len(data),
        "is_public": False,
        "is_deleted": False,
        "filename": file.filename or f"timetable.{ext}",
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    await db.uploads.insert_one(doc)
    await db.users.update_one(
        {"_id": user["_id"]},
        {"$set": {"timetable_file_id": file_id,
                  "timetable_filename": doc["filename"],
                  "timetable_uploaded_at": doc["created_at"]}},
    )
    return {
        "id": file_id,
        "filename": doc["filename"],
        "size": len(data),
        "content_type": doc["content_type"],
        "url": f"/api/uploads/{file_id}/file",
    }


@api_router.get("/timetable/me")
async def my_timetable(user: dict = Depends(get_current_user)):
    fid = user.get("timetable_file_id")
    if not fid:
        return {"has_timetable": False}
    return {
        "has_timetable": True,
        "id": fid,
        "filename": user.get("timetable_filename"),
        "uploaded_at": user.get("timetable_uploaded_at"),
        "url": f"/api/uploads/{fid}/file",
    }


# ----- Seed data -----
SEED_LOCATIONS = [
    # Entry
    {"id": "loc-main-gate",    "name": "Main Gate",              "x":  60, "y": 540, "type": "entry"},
    # Academic Zone (north / top)
    {"id": "loc-ab1",          "name": "Academic Block 1 (AB-1)","x": 210, "y": 180, "type": "academic"},
    {"id": "loc-ab2",          "name": "Academic Block 2 (AB-2)","x": 380, "y": 130, "type": "academic"},
    {"id": "loc-ab3",          "name": "Academic Block 3 (AB-3)","x": 560, "y": 180, "type": "academic"},
    {"id": "loc-library",      "name": "Central Library",        "x": 300, "y": 280, "type": "academic"},
    {"id": "loc-admin",        "name": "Administrative Block",   "x": 480, "y": 300, "type": "academic"},
    # Central
    {"id": "loc-plaza",        "name": "Central Plaza",          "x": 390, "y": 380, "type": "recreation"},
    {"id": "loc-amphi",        "name": "Amphitheatre",           "x": 230, "y": 400, "type": "event"},
    # Food
    {"id": "loc-mess",         "name": "Central Dining Hall",    "x": 350, "y": 470, "type": "food"},
    {"id": "loc-cafe",         "name": "Foodys Cafeteria",       "x": 540, "y": 440, "type": "food"},
    # Residence
    {"id": "loc-boys-hostel",  "name": "Boys Hostel Block",      "x": 690, "y": 470, "type": "residence"},
    {"id": "loc-girls-hostel", "name": "Girls Hostel Block",     "x": 130, "y": 470, "type": "residence"},
    # Sports Zone (east)
    {"id": "loc-sports",       "name": "Sports Complex",         "x": 680, "y": 230, "type": "fitness"},
    {"id": "loc-cricket",      "name": "Cricket Ground",         "x": 720, "y": 340, "type": "fitness"},
    # Utility
    {"id": "loc-health",       "name": "Health Centre",          "x": 110, "y": 320, "type": "utility"},
    {"id": "loc-bank",         "name": "SBI Branch & ATM",       "x": 170, "y": 260, "type": "utility"},
]

SEED_QUESTS = [
    {"id": "q-1",  "title": "Bhopal Gateway",              "description": "Snap a selfie at the VIT Bhopal Main Gate and share your arrival.",         "location": "Main Gate",              "location_id": "loc-main-gate",    "xp_reward":  70, "difficulty": "easy",   "category": "social",      "duration_min":  5,  "icon": "KeyRound"},
    {"id": "q-2",  "title": "AB-1 Lecture Marathon",       "description": "Attend all your AB-1 classes back-to-back without skipping.",              "location": "Academic Block 1 (AB-1)","location_id": "loc-ab1",         "xp_reward": 110, "difficulty": "medium", "category": "academic",    "duration_min": 60,  "icon": "GraduationCap"},
    {"id": "q-3",  "title": "AB-2 Innovation Sprint",      "description": "Build a working prototype in AB-2 makerspace in one afternoon.",           "location": "Academic Block 2 (AB-2)","location_id": "loc-ab2",         "xp_reward": 160, "difficulty": "hard",   "category": "academic",    "duration_min": 90,  "icon": "Zap"},
    {"id": "q-4",  "title": "AB-3 Corridor Recon",         "description": "Explore every floor of AB-3 and note the department maps.",                "location": "Academic Block 3 (AB-3)","location_id": "loc-ab3",         "xp_reward":  90, "difficulty": "easy",   "category": "exploration", "duration_min": 20,  "icon": "Search"},
    {"id": "q-5",  "title": "Library Whispers",            "description": "Find three rare books hidden across the Central Library stacks.",          "location": "Central Library",        "location_id": "loc-library",     "xp_reward":  80, "difficulty": "easy",   "category": "exploration", "duration_min": 15,  "icon": "BookOpen"},
    {"id": "q-6",  "title": "Admin Block Errand",          "description": "Collect your bonafide letter from the Administrative Block in one visit.",  "location": "Administrative Block",   "location_id": "loc-admin",       "xp_reward":  60, "difficulty": "easy",   "category": "exploration", "duration_min": 15,  "icon": "KeyRound"},
    {"id": "q-7",  "title": "Plaza Sunrise",               "description": "Meet 3 new students at the Central Plaza before 9 AM.",                     "location": "Central Plaza",          "location_id": "loc-plaza",       "xp_reward":  90, "difficulty": "easy",   "category": "social",      "duration_min": 30,  "icon": "Users"},
    {"id": "q-8",  "title": "Amphitheatre Encore",         "description": "Perform or join a jam session at the campus Amphitheatre.",                 "location": "Amphitheatre",           "location_id": "loc-amphi",       "xp_reward": 130, "difficulty": "medium", "category": "social",      "duration_min": 40,  "icon": "PartyPopper"},
    {"id": "q-9",  "title": "Mess Master Chef",            "description": "Try a Madhya Pradesh regional dish at the Central Dining Hall.",            "location": "Central Dining Hall",    "location_id": "loc-mess",        "xp_reward":  60, "difficulty": "easy",   "category": "social",      "duration_min": 20,  "icon": "Utensils"},
    {"id": "q-10", "title": "Foodys Feast",                "description": "Order the secret menu combo at Foodys Cafeteria.",                          "location": "Foodys Cafeteria",       "location_id": "loc-cafe",        "xp_reward":  70, "difficulty": "easy",   "category": "social",      "duration_min": 15,  "icon": "Utensils"},
    {"id": "q-11", "title": "Boys Hostel Trivia Night",    "description": "Organize a group trivia in the Boys Hostel common room.",                   "location": "Boys Hostel Block",      "location_id": "loc-boys-hostel", "xp_reward": 130, "difficulty": "medium", "category": "social",      "duration_min": 40,  "icon": "PartyPopper"},
    {"id": "q-12", "title": "Sunset Stroll",               "description": "Walk from Girls Hostel to Main Gate as the sun sets over Bhopal.",          "location": "Girls Hostel Block",     "location_id": "loc-girls-hostel","xp_reward":  60, "difficulty": "easy",   "category": "fitness",     "duration_min": 15,  "icon": "Sun"},
    {"id": "q-13", "title": "Iron Will",                   "description": "Complete a 20-minute workout at the Sports Complex.",                        "location": "Sports Complex",         "location_id": "loc-sports",      "xp_reward": 150, "difficulty": "hard",   "category": "fitness",     "duration_min": 20,  "icon": "Dumbbell"},
    {"id": "q-14", "title": "Cricket Ground Sprint",       "description": "Run 3 laps around the Cricket Ground boundary.",                             "location": "Cricket Ground",         "location_id": "loc-cricket",     "xp_reward": 170, "difficulty": "hard",   "category": "fitness",     "duration_min": 25,  "icon": "Timer"},
    {"id": "q-15", "title": "Wellness Check",              "description": "Visit the Health Centre for a free fitness assessment.",                     "location": "Health Centre",          "location_id": "loc-health",      "xp_reward":  80, "difficulty": "easy",   "category": "fitness",     "duration_min": 20,  "icon": "Zap"},
    {"id": "q-16", "title": "Bhopal Campus Cartographer",  "description": "Walk to every academic block in a single day.",                              "location": "AB-3",                   "location_id": "loc-ab3",         "xp_reward": 220, "difficulty": "hard",   "category": "fitness",     "duration_min": 60,  "icon": "Map"},
]


async def seed_users():
    # Admin
    admin_email = os.environ.get("ADMIN_EMAIL", "admin@vitquest.com").lower()
    admin_password = os.environ.get("ADMIN_PASSWORD", "admin123")
    admin = await db.users.find_one({"email": admin_email})
    if not admin:
        await db.users.insert_one({
            "email": admin_email,
            "password_hash": hash_password(admin_password),
            "name": "Admin",
            "role": "admin",
            "avatar_url": f"https://api.dicebear.com/7.x/adventurer/svg?seed={admin_email}",
            "xp": 3200,
            "level": _xp_to_level(3200),
            "streak_days": 12,
            "badges": ["first-quest", "explorer", "veteran"],
            "completed_quests": ["q-1", "q-2", "q-3", "q-8"],
            "created_at": datetime.now(timezone.utc).isoformat(),
        })

    # Test user
    test_email = "player@vitquest.com"
    if not await db.users.find_one({"email": test_email}):
        await db.users.insert_one({
            "email": test_email,
            "password_hash": hash_password("player123"),
            "name": "Player One",
            "role": "user",
            "avatar_url": f"https://api.dicebear.com/7.x/adventurer/svg?seed={test_email}",
            "xp": 480,
            "level": _xp_to_level(480),
            "streak_days": 4,
            "badges": ["first-quest"],
            "completed_quests": ["q-3"],
            "created_at": datetime.now(timezone.utc).isoformat(),
        })

    # Additional mock leaderboard users
    mock_players = [
        ("Nova Chen", 5240, 21, ["first-quest", "explorer", "veteran", "fit-warrior"]),
        ("Kai Reyes", 4180, 15, ["first-quest", "explorer", "veteran"]),
        ("Aria Sen", 2870, 9, ["first-quest", "explorer"]),
        ("Rohan Iyer", 2110, 7, ["first-quest", "explorer"]),
        ("Mira Das", 1560, 5, ["first-quest"]),
        ("Zayn Ali", 920, 3, ["first-quest"]),
    ]
    for name, xp, streak, badges in mock_players:
        email = name.lower().replace(" ", ".") + "@vitquest.com"
        if not await db.users.find_one({"email": email}):
            await db.users.insert_one({
                "email": email,
                "password_hash": hash_password("password123"),
                "name": name,
                "role": "user",
                "avatar_url": f"https://api.dicebear.com/7.x/adventurer/svg?seed={email}",
                "xp": xp,
                "level": _xp_to_level(xp),
                "streak_days": streak,
                "badges": badges,
                "completed_quests": [],
                "created_at": datetime.now(timezone.utc).isoformat(),
            })


async def seed_content():
    if await db.quests.count_documents({}) == 0:
        await db.quests.insert_many(SEED_QUESTS)
    if await db.locations.count_documents({}) == 0:
        await db.locations.insert_many(SEED_LOCATIONS)


@app.on_event("startup")
async def startup_event():
    await db.users.create_index("email", unique=True)
    await db.quests.create_index("id", unique=True)
    await db.locations.create_index("id", unique=True)
    await db.uploads.create_index("id", unique=True)
    await db.uploads.create_index([("owner_id", 1), ("created_at", -1)])
    await db.uploads.create_index([("is_public", 1), ("created_at", -1)])
    await db.groups.create_index("id", unique=True)
    await db.friend_requests.create_index("id", unique=True)
    await seed_users()
    await seed_content()
    if await db.groups.count_documents({}) == 0:
        await db.groups.insert_many([{**g, "member_ids": []} for g in SEED_GROUPS])
    try:
        init_storage()
    except Exception as e:
        logging.getLogger(__name__).error(f"Object storage init failed: {e}")


app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
