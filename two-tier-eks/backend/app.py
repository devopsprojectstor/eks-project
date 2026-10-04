"""Backend tier: a small Flask JSON API for a task list.

Tasks are kept in memory to keep the project focused on the deployment
pipeline. Run ONE replica (see k8s/backend.yaml); add Redis/RDS to make it 3-tier.
"""
import os
import socket
import threading
import time

from flask import Flask, jsonify, request

app = Flask(__name__)

VERSION = os.getenv("APP_VERSION", "dev")
POD_NAME = os.getenv("POD_NAME", socket.gethostname())
STARTED_AT = time.time()

_lock = threading.Lock()
_tasks = []
_next_id = 1


def _find(task_id):
    return next((t for t in _tasks if t["id"] == task_id), None)


@app.get("/api/health")
def health():
    return jsonify(status="ok")


@app.get("/api/info")
def info():
    return jsonify(
        pod=POD_NAME,
        version=VERSION,
        uptime_seconds=int(time.time() - STARTED_AT),
    )


@app.get("/api/tasks")
def list_tasks():
    with _lock:
        return jsonify(list(_tasks))


@app.post("/api/tasks")
def create_task():
    global _next_id
    data = request.get_json(silent=True) or {}
    title = str(data.get("title", "")).strip()
    if not 1 <= len(title) <= 120:
        return jsonify(error="title must be 1-120 characters"), 400
    with _lock:
        task = {"id": _next_id, "title": title, "done": False}
        _tasks.append(task)
        _next_id += 1
    return jsonify(task), 201


@app.patch("/api/tasks/<int:task_id>")
def toggle_task(task_id):
    with _lock:
        task = _find(task_id)
        if task is None:
            return jsonify(error="task not found"), 404
        task["done"] = not task["done"]
        return jsonify(task)


@app.delete("/api/tasks/<int:task_id>")
def delete_task(task_id):
    with _lock:
        task = _find(task_id)
        if task is None:
            return jsonify(error="task not found"), 404
        _tasks.remove(task)
    return "", 204


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
