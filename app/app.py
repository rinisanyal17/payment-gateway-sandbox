import os
from flask import Flask, jsonify, request

app = Flask(__name__)

# Simulated in-memory idempotency cache
IDEMPOTENCY_CACHE = {}


@app.route("/healthz", methods=["GET"])
def healthz():
    """Liveness probe endpoint."""
    return jsonify({"status": "healthy", "service": "payment-sandbox"}), 200


@app.route("/readyz", methods=["GET"])
def readyz():
    """Readiness probe endpoint verifying core service readiness."""
    return jsonify({"status": "ready"}), 200


@app.route("/v1/charges", methods=["POST"])
def process_charge():
    """Process a mock charge with idempotency validation."""
    idempotency_key = request.headers.get("Idempotency-Key")
    data = request.get_json() or {}

    if not idempotency_key:
        return jsonify({"error": "Missing Idempotency-Key header"}), 400

    if idempotency_key in IDEMPOTENCY_CACHE:
        return jsonify({
            "status": "cached",
            "message": "Transaction already processed",
            "data": IDEMPOTENCY_CACHE[idempotency_key]
        }), 200

    amount = data.get("amount")
    currency = data.get("currency", "INR")

    if not amount or not isinstance(amount, (int, float)) or amount <= 0:
        return jsonify({"error": "Invalid charge amount"}), 422

    response_payload = {
        "transaction_id": f"txn_{os.urandom(6).hex()}",
        "amount": amount,
        "currency": currency,
        "status": "succeeded"
    }

    IDEMPOTENCY_CACHE[idempotency_key] = response_payload
    return jsonify(response_payload), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
