import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from disabilities.models import PersonWithDisability, MedicalCheck
from disabilities.serializers import PersonSerializer
from django.test import RequestFactory

p = PersonWithDisability.objects.get(id=1)
factory = RequestFactory()
request = factory.get('/')
request.user = p.owner

serializer = PersonSerializer(p, context={'request': request})
data = serializer.data

print(f"Name: {data['full_name']}")
print(f"Is Checked This Year: {data['is_checked_this_year']}")
print(f"Latest Check Date: {data['latest_check_date_this_year']}")
