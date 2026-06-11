import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()
from disabilities.models import PersonWithDisability
print(f'Total People: {PersonWithDisability.objects.count()}')
print(f'With Map: {PersonWithDisability.objects.exclude(map_url="").count()}')
