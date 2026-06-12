import requests
import json

base_url = "http://127.0.0.1:8000/api"

# 1. Login to get token
login_url = "http://127.0.0.1:8000/api/token/"
login_data = {"username": "Rose", "password": "260245"} 
res = requests.post(login_url, json=login_data)
if res.status_code != 200:
    print(f"Login failed: {res.status_code}")
    print(res.text)
    exit()

token = res.json()["access"]
headers = {"Authorization": f"Bearer {token}"}

# 2. Add a MedicalCheck for Person ID 1
check_data = {
    "person": 1,
    "check_date": "2026-06-12",
    "detail": "Test check from script"
}
res = requests.post(f"{base_url}/checks/", data=check_data, headers=headers)
print(f"Create Check: {res.status_code}")
print(res.text)

# 3. Verify it exists
res = requests.get(f"{base_url}/checks/", headers=headers)
print(f"List Checks: {res.status_code}")
print(res.text)
