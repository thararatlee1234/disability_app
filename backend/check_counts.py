import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from disabilities.models import PersonWithDisability, MedicalCheck
from django.utils import timezone

now = timezone.now()
print(f"Current Server Time: {now}")
print(f"Current Year: {now.year}")

all_checks = MedicalCheck.objects.all()
print(f"Total Checks: {all_checks.count()}")

for check in all_checks[:10]:
    print(f"Person: {check.person.full_name}, Date: {check.check_date}, Year: {check.check_date.year}")

checks_this_year = MedicalCheck.objects.filter(check_date__year=now.year)
print(f"Checks this year ({now.year}): {checks_this_year.count()}")
