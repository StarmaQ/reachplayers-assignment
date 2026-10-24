"""
Uploads an art file to Roblox through the Open Cloud Assets API and prints its asset id.

    python art/upload.py art/export/FindJob.fbx Model "FindJob Building"
    python art/upload.py art/export/Clipboard.png Decal "FindJob Clipboard"

Reads UPLOAD_KEY from .env (the key needs the asset:write scope).
"""

import json
import os
import sys
import time
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CREATOR_USER_ID = "110677473"
API = "https://apis.roblox.com/assets/v1"

CONTENT_TYPES = {
    ".fbx": "model/fbx",
    ".png": "image/png",
    ".jpg": "image/jpeg",
}


def read_key():
    with open(os.path.join(ROOT, ".env")) as file:
        for line in file:
            name, _, value = line.partition("=")
            if name.strip() == "UPLOAD_KEY":
                return value.strip()
    sys.exit("UPLOAD_KEY missing from .env")


def call(method, url, key, body=None, content_type=None):
    request = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if content_type:
        request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        sys.exit(f"{error.code} {error.reason}: {error.read().decode()}")


def multipart(fields, file_name, file_bytes, file_type):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    parts.append(
        (
            f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{file_name}"\r\n'
            f"Content-Type: {file_type}\r\n\r\n"
        ).encode()
        + file_bytes
        + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def upload(path, asset_type, display_name):
    key = read_key()
    request = {
        "assetType": asset_type,
        "displayName": display_name,
        "description": "FindJob campaign asset",
        "creationContext": {"creator": {"userId": CREATOR_USER_ID}},
    }
    with open(path, "rb") as file:
        body, content_type = multipart(
            {"request": json.dumps(request)},
            os.path.basename(path),
            file.read(),
            CONTENT_TYPES[os.path.splitext(path)[1].lower()],
        )

    operation = call("POST", f"{API}/assets", key, body, content_type)
    # Uploads are processed asynchronously, poll the operation until it has an asset id
    while not operation.get("done"):
        time.sleep(2)
        operation = call("GET", f"{API}/{operation['path']}", key)

    asset_id = operation["response"]["assetId"]
    print(f"{display_name}: rbxassetid://{asset_id}")
    return asset_id


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    upload(sys.argv[1], sys.argv[2], sys.argv[3])
