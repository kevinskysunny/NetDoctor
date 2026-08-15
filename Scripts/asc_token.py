#!/usr/bin/env python3
import base64
import json
import os
import sys
import time

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
from cryptography.hazmat.primitives.serialization import load_pem_private_key


def b64url(data):
    if isinstance(data, str):
        data = data.encode()
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


key_path = os.environ.get("APP_STORE_CONNECT_API_KEY_PATH")
key_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ID")
issuer_id = os.environ.get("APP_STORE_CONNECT_ISSUER_ID")
if not key_path or not key_id or not issuer_id:
    raise SystemExit("Set APP_STORE_CONNECT_API_KEY_PATH, APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_ISSUER_ID")

key = load_pem_private_key(open(key_path, "rb").read(), password=None)
now = int(time.time())
header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
payload = {
    "iss": issuer_id,
    "iat": now,
    "exp": now + 1200,
    "aud": "appstoreconnect-v1",
}
signing_input = b64url(json.dumps(header, separators=(",", ":"))) + "." + b64url(
    json.dumps(payload, separators=(",", ":"))
)
der_signature = key.sign(signing_input.encode(), ec.ECDSA(hashes.SHA256()))
r, s = decode_dss_signature(der_signature)
raw_signature = r.to_bytes(32, "big") + s.to_bytes(32, "big")
print(signing_input + "." + b64url(raw_signature))
