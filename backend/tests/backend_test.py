"""VIT Quest backend API tests."""
import os
import uuid
import pytest
import requests

BASE_URL = os.environ.get("REACT_APP_BACKEND_URL", "https://team-claude-limit-exceeded-vansh-10.onrender.com").rstrip("/")
API = f"{BASE_URL}/api"

PLAYER_EMAIL = "player@vitquest.com"
PLAYER_PASSWORD = "player123"


@pytest.fixture(scope="session")
def session():
    s = requests.Session()
    s.headers.update({"Content-Type": "application/json"})
    return s


@pytest.fixture(scope="session")
def player_token(session):
    r = session.post(f"{API}/auth/login", json={"email": PLAYER_EMAIL, "password": PLAYER_PASSWORD})
    assert r.status_code == 200, r.text
    data = r.json()
    assert "token" in data and "user" in data
    return data["token"]


@pytest.fixture
def auth_headers(player_token):
    return {"Authorization": f"Bearer {player_token}", "Content-Type": "application/json"}


# ---- Auth ----
class TestAuth:
    def test_login_success(self, session):
        r = session.post(f"{API}/auth/login", json={"email": PLAYER_EMAIL, "password": PLAYER_PASSWORD})
        assert r.status_code == 200
        d = r.json()
        assert d["user"]["email"] == PLAYER_EMAIL
        assert d["user"]["name"] == "Player One"
        assert isinstance(d["token"], str) and len(d["token"]) > 20
        # cookie set?
        assert "access_token" in r.cookies or any(c.name == "access_token" for c in r.cookies)

    def test_login_wrong_password(self, session):
        r = session.post(f"{API}/auth/login", json={"email": PLAYER_EMAIL, "password": "wrongpass"})
        assert r.status_code == 401

    def test_me_with_bearer(self, session, player_token):
        r = session.get(f"{API}/auth/me", headers={"Authorization": f"Bearer {player_token}"})
        assert r.status_code == 200
        d = r.json()
        for k in ["id", "email", "name", "xp", "level", "badges", "completed_quests"]:
            assert k in d
        assert d["email"] == PLAYER_EMAIL
        assert "q-3" in d["completed_quests"]

    def test_me_no_auth(self, session):
        r = requests.get(f"{API}/auth/me")
        assert r.status_code == 401

    def test_register_new_user(self, session):
        email = f"test_{uuid.uuid4().hex[:8]}@vitquest.com"
        r = session.post(f"{API}/auth/register", json={
            "email": email, "password": "secret123", "name": "TEST User"
        })
        assert r.status_code == 200, r.text
        d = r.json()
        assert d["user"]["email"] == email
        assert d["user"]["xp"] == 0
        assert d["user"]["level"] == 1
        assert isinstance(d["token"], str)

    def test_register_duplicate(self, session):
        r = session.post(f"{API}/auth/register", json={
            "email": PLAYER_EMAIL, "password": "player123", "name": "dup"
        })
        assert r.status_code == 400


# ---- Quests ----
class TestQuests:
    def test_active_excludes_completed(self, session, auth_headers):
        r = session.get(f"{API}/quests/active", headers=auth_headers)
        assert r.status_code == 200
        quests = r.json()
        assert isinstance(quests, list)
        assert len(quests) <= 6
        ids = [q["id"] for q in quests]
        assert "q-3" not in ids  # player has q-3 completed

    def test_complete_quest_flow(self, session):
        # Create a fresh user to avoid state pollution
        email = f"test_{uuid.uuid4().hex[:8]}@vitquest.com"
        r = session.post(f"{API}/auth/register", json={
            "email": email, "password": "secret123", "name": "TEST Complete"
        })
        token = r.json()["token"]
        h = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

        # Complete q-1 (fitness, 120 xp)
        r = session.post(f"{API}/quests/complete", json={"quest_id": "q-1"}, headers=h)
        assert r.status_code == 200, r.text
        d = r.json()
        assert d["xp_gained"] == 120
        assert d["user"]["xp"] == 120
        assert "q-1" in d["user"]["completed_quests"]
        # first-quest badge and fit-warrior for fitness
        assert "first-quest" in d["user"]["badges"]
        assert "fit-warrior" in d["user"]["badges"]

        # Level from sqrt(120/100) = 1.09 -> 1+1=2
        assert d["user"]["level"] == 2

        # Complete again -> 400
        r = session.post(f"{API}/quests/complete", json={"quest_id": "q-1"}, headers=h)
        assert r.status_code == 400

        # Invalid quest -> 404
        r = session.post(f"{API}/quests/complete", json={"quest_id": "does-not-exist"}, headers=h)
        assert r.status_code == 404

    def test_list_quests(self, session, auth_headers):
        r = session.get(f"{API}/quests", headers=auth_headers)
        assert r.status_code == 200
        quests = r.json()
        assert len(quests) == 12


# ---- Leaderboard ----
class TestLeaderboard:
    def test_leaderboard_sorted(self, player_token):
        # Use a clean session to avoid cookie precedence from previous tests
        r = requests.get(f"{API}/leaderboard", headers={"Authorization": f"Bearer {player_token}"})
        assert r.status_code == 200
        rows = r.json()
        assert len(rows) >= 7
        xps = [row["xp"] for row in rows]
        assert xps == sorted(xps, reverse=True)
        assert rows[0]["rank"] == 1
        # is_you must be set for exactly one row (the player)
        yous = [row for row in rows if row["is_you"]]
        assert len(yous) == 1
        assert yous[0]["name"] == "Player One"
        # avatar_url present
        assert all("avatar_url" in row for row in rows)


# ---- Locations ----
class TestLocations:
    def test_locations_seeded(self, session, auth_headers):
        r = session.get(f"{API}/locations", headers=auth_headers)
        assert r.status_code == 200
        locs = r.json()
        assert len(locs) == 12
        for loc in locs:
            assert "id" in loc and "x" in loc and "y" in loc and "type" in loc
