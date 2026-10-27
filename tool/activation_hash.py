"""Turns the RA7AL_ACTIVATION_CODE secret into a PBKDF2-SHA256 hash + salt.

Prints GitHub Actions env lines (ACT_HASH=..., ACT_SALT=...). The plain code is
never written to the build output or the app. No secret set -> prints nothing,
and the app runs without an activation screen.
"""
import hashlib
import os
import secrets

ITERATIONS = 120000  # must match lib/services/activation.dart

code = os.environ.get("CODE", "").strip()
if code:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", code.encode("utf-8"), salt, ITERATIONS, 32)
    print(f"ACT_HASH={digest.hex()}")
    print(f"ACT_SALT={salt.hex()}")
