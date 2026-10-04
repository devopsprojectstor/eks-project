import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from app import app  # noqa: E402


def client():
    app.config["TESTING"] = True
    return app.test_client()


def test_health():
    r = client().get("/api/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_info_has_pod_and_version():
    data = client().get("/api/info").get_json()
    assert "pod" in data and "version" in data


def test_create_toggle_delete_task():
    c = client()
    r = c.post("/api/tasks", json={"title": "Write Dockerfile"})
    assert r.status_code == 201
    task_id = r.get_json()["id"]

    assert any(t["id"] == task_id for t in c.get("/api/tasks").get_json())
    assert c.patch(f"/api/tasks/{task_id}").get_json()["done"] is True
    assert c.delete(f"/api/tasks/{task_id}").status_code == 204
    assert c.delete(f"/api/tasks/{task_id}").status_code == 404


def test_rejects_empty_title():
    assert client().post("/api/tasks", json={"title": "  "}).status_code == 400
