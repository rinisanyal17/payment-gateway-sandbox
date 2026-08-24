import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_healthz(client):
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.get_json()["status"] == "healthy"


def test_readyz(client):
    res = client.get("/readyz")
    assert res.status_code == 200
    assert res.get_json()["status"] == "ready"


def test_charge_missing_idempotency_header(client):
    res = client.post("/v1/charges", json={"amount": 500})
    assert res.status_code == 400


def test_charge_success_and_idempotency(client):
    headers = {"Idempotency-Key": "test-key-12345"}
    payload = {"amount": 1000, "currency": "INR"}

    # Initial transaction
    res1 = client.post("/v1/charges", headers=headers, json=payload)
    assert res1.status_code == 201
    assert res1.get_json()["status"] == "succeeded"

    # Duplicate call returns cached state
    res2 = client.post("/v1/charges", headers=headers, json=payload)
    assert res2.status_code == 200
    assert res2.get_json()["status"] == "cached"
