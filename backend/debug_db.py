import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from disabilities.models import PersonWithDisability, MedicalCheck

print("--- PersonWithDisability ---")
for p in PersonWithDisability.objects.all():
    print(f"ID: {p.id}, Name: {p.full_name}, Owner: {p.owner.username if p.owner else 'None'}")

print("\n--- MedicalCheck ---")
for c in MedicalCheck.objects.all():
    print(f"ID: {c.id}, Person ID: {c.person_id}, Name: {c.person.full_name}, Owner: {c.person.owner.username if c.person.owner else 'None'}, Date: {c.check_date}, Detail: {c.detail}")
