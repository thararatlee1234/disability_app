import shutil
import tempfile

from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework.test import APIClient

from .models import PersonWithDisability


class MedicalCheckApiTests(TestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls._media_root = tempfile.mkdtemp()
        cls._settings_override = override_settings(MEDIA_ROOT=cls._media_root)
        cls._settings_override.enable()

    @classmethod
    def tearDownClass(cls):
        cls._settings_override.disable()
        shutil.rmtree(cls._media_root, ignore_errors=True)
        super().tearDownClass()

    def setUp(self):
        User = get_user_model()
        self.user = User.objects.create_user(username='klong', password='pass12345')
        self.other_user = User.objects.create_user(username='other', password='pass12345')
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.person = PersonWithDisability.objects.create(
            owner=self.user,
            first_name='Somchai',
            last_name='Jaidee',
        )

    def _image(self, name='photo.jpg', size=1024):
        return SimpleUploadedFile(
            name,
            b'a' * size,
            content_type='image/jpeg',
        )

    def test_create_medical_check_with_date_detail_and_photos(self):
        response = self.client.post(
            '/api/checks/',
            {
                'person': self.person.id,
                'check_date': '2026-06-04',
                'detail': 'ตรวจเยี่ยมบ้าน',
                'photos': [self._image('one.jpg'), self._image('two.jpg')],
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['person'], self.person.id)
        self.assertEqual(response.data['check_date'], '2026-06-04')
        self.assertEqual(response.data['detail'], 'ตรวจเยี่ยมบ้าน')
        self.assertEqual(len(response.data['photos']), 2)

    def test_rejects_more_than_five_medical_check_photos(self):
        response = self.client.post(
            '/api/checks/',
            {
                'person': self.person.id,
                'check_date': '2026-06-04',
                'detail': 'มีรูปมากเกินไป',
                'photos': [self._image(f'{index}.jpg') for index in range(6)],
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn('photos', response.data)

    def test_rejects_medical_check_photo_larger_than_50_mb(self):
        response = self.client.post(
            '/api/checks/',
            {
                'person': self.person.id,
                'check_date': '2026-06-04',
                'detail': 'รูปใหญ่เกินไป',
                'photos': [self._image('large.jpg', 50 * 1024 * 1024 + 1)],
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn('photos', response.data)

    def test_update_medical_check(self):
        check = self.client.post(
            '/api/checks/',
            {
                'person': self.person.id,
                'check_date': '2026-06-04',
                'detail': 'Original Detail',
            },
            format='multipart'
        ).data

        response = self.client.patch(
            f'/api/checks/{check["id"]}/',
            {
                'detail': 'Updated Detail',
                'photos': [self._image('new_photo.jpg')],
            },
            format='multipart'
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['detail'], 'Updated Detail')
        self.assertEqual(len(response.data['photos']), 1)

    def test_delete_medical_check(self):
        check = self.client.post(
            '/api/checks/',
            {
                'person': self.person.id,
                'check_date': '2026-06-04',
                'detail': 'To be deleted',
            },
            format='multipart'
        ).data

        response = self.client.delete(f'/api/checks/{check["id"]}/')
        self.assertEqual(response.status_code, 204)
        
        # Verify it's gone
        response = self.client.get(f'/api/checks/{check["id"]}/')
        self.assertEqual(response.status_code, 404)


class UserIsolationApiTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.klong = User.objects.create_user(username='klong', password='pass12345')
        self.other = User.objects.create_user(username='other', password='pass12345')
        self.klong_client = APIClient()
        self.klong_client.force_authenticate(self.klong)
        self.other_client = APIClient()
        self.other_client.force_authenticate(self.other)
        self.klong_person = PersonWithDisability.objects.create(
            owner=self.klong,
            first_name='Klong',
            last_name='Owner',
        )
        self.other_person = PersonWithDisability.objects.create(
            owner=self.other,
            first_name='Other',
            last_name='Owner',
        )

    def test_requires_login_to_read_persons(self):
        response = APIClient().get('/api/persons/')

        self.assertEqual(response.status_code, 401)

    def test_user_only_sees_own_people(self):
        response = self.klong_client.get('/api/persons/')

        self.assertEqual(response.status_code, 200)
        names = [item['first_name'] for item in response.data['results']]
        self.assertEqual(names, ['Klong'])

    def test_created_person_owner_is_request_user(self):
        response = self.klong_client.post(
            '/api/persons/',
            {
                'first_name': 'New',
                'last_name': 'Person',
            },
        )

        self.assertEqual(response.status_code, 201)
        created = PersonWithDisability.objects.get(id=response.data['id'])
        self.assertEqual(created.owner, self.klong)

    def test_user_cannot_update_other_users_person(self):
        response = self.klong_client.patch(
            f'/api/persons/{self.other_person.id}/',
            {'first_name': 'Hacked'},
        )

        self.assertEqual(response.status_code, 404)
        self.other_person.refresh_from_db()
        self.assertEqual(self.other_person.first_name, 'Other')

    def test_stats_are_limited_to_request_user(self):
        response = self.klong_client.get('/api/stats/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['total'], 1)

    def test_user_cannot_create_check_for_other_users_person(self):
        response = self.klong_client.post(
            '/api/checks/',
            {
                'person': self.other_person.id,
                'check_date': '2026-06-04',
                'detail': 'Not allowed',
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 400)


class TokenApiTests(TestCase):
    def test_token_login_is_case_insensitive_for_username(self):
        User = get_user_model()
        User.objects.create_user(username='Rose', password='pass12345')

        response = APIClient().post(
            '/api/token/',
            {'username': 'rose', 'password': 'pass12345'},
            format='json',
            HTTP_HOST='127.0.0.1',
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)


class RoseAdminUserManagementTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.rose = User.objects.create_superuser(username='Rose', password='pass12345')
        self.other_admin = User.objects.create_superuser(username='Admin2', password='pass12345')

    def test_rose_can_open_user_add_admin_page(self):
        self.client.force_login(self.rose)

        response = self.client.get(reverse('admin:auth_user_add'))

        self.assertEqual(response.status_code, 200)

    def test_non_rose_admin_cannot_open_user_add_admin_page(self):
        self.client.force_login(self.other_admin)

        response = self.client.get(reverse('admin:auth_user_add'))

        self.assertEqual(response.status_code, 403)
