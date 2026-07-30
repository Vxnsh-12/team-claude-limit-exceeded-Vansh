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

from fastapi import FastAPI, APIRouter, HTTPException, Depends, Request, Response
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, Field, EmailStr, BeforeValidator, ConfigDict


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


# ----- Seed data -----
SEED_LOCATIONS = [
    {"id": "loc-main-gate",    "name": "Main Gate",             "x": 50,  "y": 380, "type": "entry"},
    {"id": "loc-tt",           "name": "Technology Tower",      "x": 180, "y": 300, "type": "academic"},
    {"id": "loc-library",      "name": "Central Library",       "x": 300, "y": 220, "type": "academic"},
    {"id": "loc-gd-naidu",     "name": "G.D. Naidu Block",      "x": 430, "y": 160, "type": "academic"},
    {"id": "loc-smv",          "name": "SMV Block",             "x": 520, "y": 260, "type": "academic"},
    {"id": "loc-sjt",          "name": "Silver Jubilee Tower",  "x": 640, "y": 200, "type": "academic"},
    {"id": "loc-food-court",   "name": "Food Court",            "x": 380, "y": 380, "type": "food"},
    {"id": "loc-anna-audi",    "name": "Anna Auditorium",       "x": 220, "y": 460, "type": "event"},
    {"id": "loc-gym",          "name": "VIT Gym",               "x": 560, "y": 420, "type": "fitness"},
    {"id": "loc-mens-hostel",  "name": "Men's Hostel",          "x": 700, "y": 350, "type": "residence"},
    {"id": "loc-ladies-hostel","name": "Ladies Hostel",         "x": 100, "y": 500, "type": "residence"},
    {"id": "loc-lawn",         "name": "Central Lawn",          "x": 360, "y": 300, "type": "recreation"},
]

SEED_QUESTS = [
    {"id": "q-1", "title": "Sprint to the Summit",        "description": "Reach the top floor of Technology Tower within 5 minutes.",       "location": "Technology Tower",     "location_id": "loc-tt",         "xp_reward": 120, "difficulty": "medium", "category": "fitness",     "duration_min": 5,  "icon": "Zap"},
    {"id": "q-2", "title": "Whispers of the Library",     "description": "Locate three rare books hidden across the Central Library.",       "location": "Central Library",       "location_id": "loc-library",    "xp_reward": 80,  "difficulty": "easy",   "category": "exploration", "duration_min": 15, "icon": "BookOpen"},
    {"id": "q-3", "title": "Food Court Feast",            "description": "Try a dish you've never eaten before at the Food Court.",          "location": "Food Court",            "location_id": "loc-food-court", "xp_reward": 60,  "difficulty": "easy",   "category": "social",      "duration_min": 20, "icon": "Utensils"},
    {"id": "q-4", "title": "Iron Will",                   "description": "Complete a 20-minute workout at the VIT Gym.",                     "location": "VIT Gym",               "location_id": "loc-gym",        "xp_reward": 150, "difficulty": "hard",   "category": "fitness",     "duration_min": 20, "icon": "Dumbbell"},
    {"id": "q-5", "title": "Auditorium Enigma",           "description": "Find the hidden emblem etched inside Anna Auditorium.",            "location": "Anna Auditorium",       "location_id": "loc-anna-audi",  "xp_reward": 100, "difficulty": "medium", "category": "exploration", "duration_min": 10, "icon": "Search"},
    {"id": "q-6", "title": "Campus Cartographer",         "description": "Walk to all six academic blocks in a single day.",                 "location": "SJT Block",             "location_id": "loc-sjt",        "xp_reward": 220, "difficulty": "hard",   "category": "fitness",     "duration_min": 60, "icon": "Map"},
    {"id": "q-7", "title": "Social Sunrise",              "description": "Meet 3 new students on the Central Lawn before 9 AM.",             "location": "Central Lawn",          "location_id": "loc-lawn",       "xp_reward": 90,  "difficulty": "easy",   "category": "social",      "duration_min": 30, "icon": "Users"},
    {"id": "q-8", "title": "Gatekeeper's Riddle",         "description": "Solve the riddle inscribed near the Main Gate.",                   "location": "Main Gate",             "location_id": "loc-main-gate",  "xp_reward": 70,  "difficulty": "easy",   "category": "exploration", "duration_min": 8,  "icon": "KeyRound"},
    {"id": "q-9", "title": "SMV Study Sprint",            "description": "Attend a live lecture and take three insightful notes.",           "location": "SMV Block",             "location_id": "loc-smv",        "xp_reward": 110, "difficulty": "medium", "category": "academic",    "duration_min": 45, "icon": "GraduationCap"},
    {"id": "q-10","title": "Sunset Stroll",               "description": "Walk from Ladies Hostel to Main Gate as the sun sets.",            "location": "Ladies Hostel",         "location_id": "loc-ladies-hostel","xp_reward": 60,"difficulty": "easy",  "category": "fitness",     "duration_min": 15, "icon": "Sun"},
    {"id": "q-11","title": "Hostel Havoc",                "description": "Organize a group trivia in the Men's Hostel common room.",         "location": "Men's Hostel",          "location_id": "loc-mens-hostel","xp_reward": 130, "difficulty": "medium", "category": "social",      "duration_min": 40, "icon": "PartyPopper"},
    {"id": "q-12","title": "Silver Jubilee Sprint",       "description": "Run 3 laps around Silver Jubilee Tower.",                          "location": "Silver Jubilee Tower",  "location_id": "loc-sjt",        "xp_reward": 170, "difficulty": "hard",   "category": "fitness",     "duration_min": 25, "icon": "Timer"},
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
    await seed_users()
    await seed_content()


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
