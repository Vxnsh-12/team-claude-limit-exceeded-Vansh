"""Tests for new features: timetable upload, groups join/leave, users location/nearby, friend requests."""
import io
import os
import uuid
import pytest
import requests

BASE_URL = os.environ.get("REACT_APP_BACKEND_URL", "https://team-claude-limit-exceeded-vansh-10.onrender.com").rstrip("/")
API = f"{BASE_URL}/api"

PLAYER = ("player@vitquest.com", "player123")
ADMIN = ("admin@vitquest.com", "admin123")

# VIT Vellore approx
PLAYER_LOC = {"lat": 12.9698, "lng": 79.1559}
ADMIN_LOC = {"lat": 12.96983, "lng": 79.15593}  # ~few meters away


def _login(email, password):
    r = requests.post(f"{API}/auth/login", json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return r.json()["token"], r.json()["user"]["id"]


@pytest.fixture(scope="module")
def player():
    tok, uid = _login(*PLAYER)
    return {"token": tok, "id": uid, "h": {"Authorization": f"Bearer {tok}"}}


@pytest.fixture(scope="module")
def admin():
    tok, uid = _login(*ADMIN)
    return {"token": tok, "id": uid, "h": {"Authorization": f"Bearer {tok}"}}


# ---- Timetable ----
class TestTimetable:
    def test_upload_pdf_and_me(self, player):
        pdf = b"%PDF-1.4\n%fake\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF"
        files = {"file": ("TEST_timetable.pdf", io.BytesIO(pdf), "application/pdf")}
        r = requests.post(f"{API}/timetable/upload", files=files, headers=player["h"])
        assert r.status_code == 200, r.text
        d = r.json()
        for k in ["id", "filename", "size", "content_type", "url"]:
            assert k in d
        assert d["filename"] == "TEST_timetable.pdf"
        assert d["content_type"] == "application/pdf"

        me = requests.get(f"{API}/timetable/me", headers=player["h"])
        assert me.status_code == 200
        me_data = me.json()
        assert me_data["has_timetable"] is True
        assert me_data["filename"] == "TEST_timetable.pdf"

    def test_upload_rejects_bad_type(self, player):
        files = {"file": ("bad.exe", io.BytesIO(b"MZ\x00"), "application/x-msdownload")}
        r = requests.post(f"{API}/timetable/upload", files=files, headers=player["h"])
        assert r.status_code == 400

    def test_upload_requires_auth(self):
        files = {"file": ("x.pdf", io.BytesIO(b"%PDF"), "application/pdf")}
        r = requests.post(f"{API}/timetable/upload", files=files)
        assert r.status_code in (401, 403)


# ---- Groups ----
class TestGroups:
    def test_list_returns_seeded(self, player):
        r = requests.get(f"{API}/groups", headers=player["h"])
        assert r.status_code == 200
        groups = r.json()
        assert len(groups) == 3
        ids = {g["id"] for g in groups}
        assert ids == {"g-ab1-study", "g-hackathon", "g-fit-squad"}
        for g in groups:
            assert "member_count" in g and "joined" in g

    def test_join_leave_flow(self, player):
        gid = "g-hackathon"
        # ensure clean state
        requests.post(f"{API}/groups/{gid}/leave", headers=player["h"])
        before = next(g for g in requests.get(f"{API}/groups", headers=player["h"]).json() if g["id"] == gid)

        r = requests.post(f"{API}/groups/{gid}/join", headers=player["h"])
        assert r.status_code == 200
        assert r.json()["joined"] is True

        after = next(g for g in requests.get(f"{API}/groups", headers=player["h"]).json() if g["id"] == gid)
        assert after["joined"] is True
        assert after["member_count"] == before["member_count"] + 1

        r = requests.post(f"{API}/groups/{gid}/leave", headers=player["h"])
        assert r.status_code == 200
        left = next(g for g in requests.get(f"{API}/groups", headers=player["h"]).json() if g["id"] == gid)
        assert left["joined"] is False
        assert left["member_count"] == before["member_count"]

    def test_join_unknown_group(self, player):
        r = requests.post(f"{API}/groups/nonexistent-xyz/join", headers=player["h"])
        assert r.status_code == 404


# ---- Location / Nearby ----
class TestNearby:
    def test_update_location(self, player, admin):
        r = requests.put(f"{API}/users/location", json=PLAYER_LOC, headers=player["h"])
        assert r.status_code == 200
        r = requests.put(f"{API}/users/location", json=ADMIN_LOC, headers=admin["h"])
        assert r.status_code == 200

    def test_nearby_finds_admin_within_50m(self, player, admin):
        requests.put(f"{API}/users/location", json=PLAYER_LOC, headers=player["h"])
        requests.put(f"{API}/users/location", json=ADMIN_LOC, headers=admin["h"])
        r = requests.get(f"{API}/users/nearby?radius_m=50", headers=player["h"])
        assert r.status_code == 200
        rows = r.json()
        assert any(u["id"] == admin["id"] for u in rows), rows
        admin_row = next(u for u in rows if u["id"] == admin["id"])
        for k in ["id", "name", "avatar_url", "level", "distance_m", "friend_status"]:
            assert k in admin_row
        assert admin_row["distance_m"] <= 50

    def test_nearby_excludes_far_users(self, player, admin):
        # Move admin far away (~5km)
        requests.put(f"{API}/users/location", json={"lat": 12.9698 + 0.05, "lng": 79.1559}, headers=admin["h"])
        requests.put(f"{API}/users/location", json=PLAYER_LOC, headers=player["h"])
        r = requests.get(f"{API}/users/nearby?radius_m=50", headers=player["h"])
        assert r.status_code == 200
        assert not any(u["id"] == admin["id"] for u in r.json())
        # restore
        requests.put(f"{API}/users/location", json=ADMIN_LOC, headers=admin["h"])


# ---- Friend Requests ----
class TestFriendRequests:
    def _clear(self, a, b):
        # Best effort: decline any pending requests
        for u in (a, b):
            reqs = requests.get(f"{API}/friends/requests", headers=u["h"]).json()
            for r in reqs:
                requests.post(f"{API}/friends/requests/{r['id']}/decline", headers=u["h"])

    def test_full_flow(self, player, admin):
        # Register two fresh users so state is clean
        e1 = f"TEST_{uuid.uuid4().hex[:8]}@vitquest.com"
        e2 = f"TEST_{uuid.uuid4().hex[:8]}@vitquest.com"
        u1 = requests.post(f"{API}/auth/register", json={"email": e1, "password": "pass1234", "name": "TEST U1"}).json()
        u2 = requests.post(f"{API}/auth/register", json={"email": e2, "password": "pass1234", "name": "TEST U2"}).json()
        h1 = {"Authorization": f"Bearer {u1['token']}"}
        h2 = {"Authorization": f"Bearer {u2['token']}"}

        # u1 sends to u2 -> pending
        r = requests.post(f"{API}/friends/requests", json={"to_user_id": u2["user"]["id"]}, headers=h1)
        assert r.status_code == 200
        assert r.json()["status"] == "pending"

        # u2 lists incoming -> sees 1
        inc = requests.get(f"{API}/friends/requests", headers=h2).json()
        assert len(inc) >= 1
        my_req = next(x for x in inc if x["from"]["id"] == u1["user"]["id"])
        assert my_req["from"]["name"] == "TEST U1"

        # u2 accepts
        r = requests.post(f"{API}/friends/requests/{my_req['id']}/accept", headers=h2)
        assert r.status_code == 200

        # Both have friend now
        f1 = requests.get(f"{API}/friends", headers=h1).json()
        f2 = requests.get(f"{API}/friends", headers=h2).json()
        assert any(f["id"] == u2["user"]["id"] for f in f1)
        assert any(f["id"] == u1["user"]["id"] for f in f2)

    def test_mirror_auto_accept(self):
        e1 = f"TEST_{uuid.uuid4().hex[:8]}@vitquest.com"
        e2 = f"TEST_{uuid.uuid4().hex[:8]}@vitquest.com"
        u1 = requests.post(f"{API}/auth/register", json={"email": e1, "password": "pass1234", "name": "TEST M1"}).json()
        u2 = requests.post(f"{API}/auth/register", json={"email": e2, "password": "pass1234", "name": "TEST M2"}).json()
        h1 = {"Authorization": f"Bearer {u1['token']}"}
        h2 = {"Authorization": f"Bearer {u2['token']}"}

        # u1 -> u2 (pending)
        r = requests.post(f"{API}/friends/requests", json={"to_user_id": u2["user"]["id"]}, headers=h1)
        assert r.json()["status"] == "pending"
        # u2 -> u1 (should auto-accept)
        r = requests.post(f"{API}/friends/requests", json={"to_user_id": u1["user"]["id"]}, headers=h2)
        assert r.status_code == 200
        assert r.json()["status"] == "accepted"

        f1 = requests.get(f"{API}/friends", headers=h1).json()
        assert any(f["id"] == u2["user"]["id"] for f in f1)

    def test_self_friend_rejected(self, player):
        r = requests.post(f"{API}/friends/requests", json={"to_user_id": player["id"]}, headers=player["h"])
        assert r.status_code == 400
