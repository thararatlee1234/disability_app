import os
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from disabilities.models import PersonWithDisability

class Command(BaseCommand):
    help = 'Create default admin user'
    def handle(self, *args, **options):
        username = os.getenv('ADMIN_USERNAME', 'Rose')
        password = os.getenv('ADMIN_PASSWORD', '260245')
        User = get_user_model()
        user, created = User.objects.get_or_create(username=username, defaults={'is_staff': True, 'is_superuser': True})
        user.is_staff = True
        user.is_superuser = True
        user.set_password(password)
        user.save()
        assigned = PersonWithDisability.objects.filter(owner__isnull=True).update(owner=user)
        self.stdout.write(self.style.SUCCESS(f'Admin ready: {username}'))
        if assigned:
            self.stdout.write(self.style.SUCCESS(f'Assigned unowned records to {username}: {assigned}'))
