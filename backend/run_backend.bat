@echo off
python -m venv venv
call venv\Scripts\activate
pip install -r requirements.txt
if not exist .env copy .env.example .env
python manage.py migrate
python manage.py seed_admin
python manage.py import_disabilities data\disabilities.xlsx
python manage.py runserver 0.0.0.0:8000
pause
