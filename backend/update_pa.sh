#!/bin/bash

# Update script for PythonAnywhere
# Usage: ./update_pa.sh

echo ">>> Pulling latest changes from Git..."
git pull

echo ">>> Activating virtual environment..."
# Adjust the path to your virtualenv if different
source venv/bin/activate

echo ">>> Installing/Updating requirements..."
pip install -r requirements.txt

echo ">>> Running database migrations..."
python manage.py migrate

echo ">>> Collecting static files..."
python manage.py collectstatic --noinput

echo ">>> Reloading Web App..."
# Replace 'yourusername.pythonanywhere.com' with your actual domain
# This touches the WSGI file to trigger a reload
touch /var/www/$(whoami)_pythonanywhere_com_wsgi.py

echo ">>> Done! Please check your site."
