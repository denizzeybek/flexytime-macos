#!/usr/bin/env python3
"""
Flexytime API Format Test Script
---------------------------------
Bu script dummy data oluşturur, .trc paketine çevirir ve backend'e gönderir.
Amacı: Tarih formatının doğru olup olmadığını test etmek.

Kullanım: python3 scripts/test-api-format.py
"""

import json
import hashlib
import base64
import os
import tempfile
import zipfile
import requests
from datetime import datetime
from pathlib import Path

# ============ CONFIGURATION ============

SERVICE_HOST = "test.api.flexytime.com"
SERVICE_KEY = "Ji8Zyj7JZkaisBhVypaD6Q"
CONTROL_KEY = "53201045-1b89-47d4-909e-f0d326f393c0"
# Real UserPath for: Deniz-MacBook-Pro-2.local\denizzeybek
USER_PATH = "BB8E7CFBE6955126F7902022C92DFB09BEDD78764A8E8E5183A1BD67D29E620C"

# Two-layer encryption passwords (from Configuration.swift)
INTERNAL_PASSWORD = "99C5CB2EAA4EF8C3AB722F6B320FF006022783D063DC60DE217300B6A631A91B"
EXTERNAL_PASSWORD = "23D405A00C105E32447B3700535CE159C820825658A6989208E16A1F1797F5BB"

# ============ DATE FORMAT ============

def format_date_v1(dt: datetime) -> str:
    """V1 Python format uses isoformat() which outputs: 2021-05-07T10:30:00.000000+00:00"""
    # V1 uses datetime.now(timezone.utc).isoformat() which gives +00:00 suffix
    return dt.isoformat()

# ============ DUMMY DATA ============

def create_dummy_usage() -> dict:
    """Create dummy usage data matching V1 format"""
    from datetime import timezone, timedelta

    # V1 uses UTC time!
    now = datetime.now(timezone.utc)

    # View started 2 minutes ago, ended 1 minute ago
    view_start = now - timedelta(minutes=2)
    view_end = now - timedelta(minutes=1)

    return {
        "DeviceType": 1,  # Mac
        "Version": "2.0.0",
        "Username": "Deniz-MacBook-Pro-2.local\\denizzeybek",
        "MachineName": "Deniz-MacBook-Pro-2.local",
        "IpAddress": "192.168.1.100",
        "DataType": 0,  # Input (normal activity)
        "RecordDate": format_date_v1(now),
        "Views": [
            {
                "ProcessName": "chrome",  # Backend expects lowercase
                "Title": "GitHub - Test Page - Google Chrome",
                "Time": format_date_v1(view_start),
                "ExpireTime": format_date_v1(view_end)
            },
            {
                "ProcessName": "safari",
                "Title": "Apple - Safari",
                "Time": format_date_v1(view_end),
                "ExpireTime": format_date_v1(now)
            }
        ]
    }

# ============ ZIP ENCRYPTION ============

def create_password_zip(input_path: str, output_path: str, filename_in_zip: str, password: str):
    """Create password-protected ZIP file using pyminizip"""
    try:
        import pyminizip
        pyminizip.compress(input_path, None, output_path, password, 5)

        # pyminizip doesn't let us set filename inside zip, so we need to rename
        # Actually pyminizip uses the original filename, let's use a workaround

        # Create temp dir, copy file with desired name, then zip
        temp_dir = tempfile.mkdtemp()
        temp_file = os.path.join(temp_dir, filename_in_zip)

        with open(input_path, 'rb') as f:
            content = f.read()
        with open(temp_file, 'wb') as f:
            f.write(content)

        pyminizip.compress(temp_file, None, output_path, password, 5)

        # Cleanup
        os.remove(temp_file)
        os.rmdir(temp_dir)

    except ImportError:
        print("⚠️  pyminizip not installed. Using zipfile (no password protection)")
        print("   Install with: pip3 install pyminizip")
        print("")

        # Fallback: create zip without password (for testing structure)
        with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
            zf.write(input_path, filename_in_zip)

def create_trc_file(usage: dict) -> tuple[str, datetime]:
    """Create .trc file with two-layer encryption"""

    temp_dir = tempfile.mkdtemp()

    # Step 1: Save JSON
    json_path = os.path.join(temp_dir, "usage.json")
    json_data = json.dumps(usage, indent=2, ensure_ascii=False)

    print(f"📄 JSON Data ({len(json_data)} bytes):")
    print("-" * 50)
    print(json_data)
    print("-" * 50)
    print("")

    with open(json_path, 'w', encoding='utf-8') as f:
        f.write(json_data)

    # Step 2: Calculate SHA256 hash of JSON
    json_hash = hashlib.sha256(json_data.encode('utf-8')).hexdigest().upper()
    print(f"🔑 JSON SHA256: {json_hash[:32]}...")

    # Step 3: Inner ZIP (password = INTERNAL_PASSWORD, entry name = "usage.json")
    inner_zip_path = os.path.join(temp_dir, "inner.zip")
    create_password_zip(json_path, inner_zip_path, "usage.json", INTERNAL_PASSWORD)

    inner_size = os.path.getsize(inner_zip_path)
    print(f"📦 Inner ZIP: {inner_size} bytes")

    # Step 4: Outer ZIP (password = EXTERNAL_PASSWORD, entry name = SHA256 hash)
    # Calculate ticks since epoch (seconds since year 1)
    now = datetime.now()
    epoch = datetime(1, 1, 1)
    ticks = int((now - epoch).total_seconds())

    trc_filename = f"{ticks}.trc"
    trc_path = os.path.join(temp_dir, trc_filename)

    create_password_zip(inner_zip_path, trc_path, json_hash, EXTERNAL_PASSWORD)

    trc_size = os.path.getsize(trc_path)
    print(f"📦 TRC File: {trc_filename} ({trc_size} bytes)")

    # Cleanup inner files
    os.remove(json_path)
    os.remove(inner_zip_path)

    return trc_path, now

# ============ API CALL ============

def send_to_api(trc_path: str, record_date: datetime) -> dict:
    """Send .trc file to backend API"""

    with open(trc_path, 'rb') as f:
        file_data = f.read()

    base64_content = base64.b64encode(file_data).decode('utf-8')

    payload = {
        "ControlKey": CONTROL_KEY,
        "Token": SERVICE_KEY,
        "RecordDate": format_date_v1(record_date),
        "Content": base64_content,
        "UserPath": USER_PATH,
        "DeviceType": 1  # Mac
    }

    print(f"\n🌐 Sending to API...")
    print(f"   URL: https://{SERVICE_HOST}/api/service/savetrace")
    print(f"   Content size: {len(base64_content)} bytes (base64)")
    print(f"   RecordDate: {payload['RecordDate']}")

    headers = {
        "Content-Type": "application/json",
        "Accept": "text/plain"
    }

    # Try HTTPS first, then HTTP
    for proto in ["https", "http"]:
        url = f"{proto}://{SERVICE_HOST}/api/service/savetrace"
        try:
            import json as json_module
            response = requests.post(
                url,
                data=json_module.dumps(payload),
                headers=headers,
                timeout=30
            )
            print(f"\n📬 Response ({proto}):")
            print(f"   Status Code: {response.status_code}")
            print(f"   Body: {response.text}")

            if response.status_code == 200:
                try:
                    return response.json()
                except:
                    return {"raw": response.text}
        except Exception as e:
            print(f"   {proto} failed: {e}")
            continue

    return {"error": "All protocols failed"}

# ============ MAIN ============

def main():
    print("=" * 60)
    print("🧪 Flexytime API Format Test")
    print("=" * 60)
    print("")

    # Create dummy data
    print("1️⃣  Creating dummy usage data...")
    usage = create_dummy_usage()
    print("")

    # Create .trc file
    print("2️⃣  Creating .trc package...")
    trc_path, record_date = create_trc_file(usage)
    print("")

    # Send to API
    print("3️⃣  Sending to backend API...")
    result = send_to_api(trc_path, record_date)

    # Cleanup
    os.remove(trc_path)
    parent_dir = os.path.dirname(trc_path)
    if os.path.exists(parent_dir) and not os.listdir(parent_dir):
        os.rmdir(parent_dir)

    print("")
    print("=" * 60)
    if isinstance(result, dict) and result.get("Status") == 0:
        print("✅ SUCCESS! Data format is correct.")
    else:
        print("❌ FAILED! Check the response above.")
    print("=" * 60)

if __name__ == "__main__":
    main()
