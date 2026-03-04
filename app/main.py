"""
Minimal Flask app for DevOps pipeline demo.
Exposes / (info) and /health for probes.
"""
import os
from flask import Flask, jsonify

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENV = os.environ.get("ENV", "dev")


@app.route("/")
def index():
    return jsonify({
        "service": "demo-app",
        "version": VERSION,
        "env": ENV,
        "status": "ok",
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
