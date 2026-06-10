from django.conf import settings
from django.db import models

class PersonWithDisability(models.Model):
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='people', on_delete=models.CASCADE, null=True, blank=True)
    citizen_id = models.CharField('เลขบัตรประชาชน', max_length=32, blank=True, db_index=True)
    prefix = models.CharField('คำนำหน้า', max_length=50, blank=True)
    first_name = models.CharField('ชื่อ', max_length=150, db_index=True)
    last_name = models.CharField('นามสกุล', max_length=150, db_index=True)
    gender = models.CharField('เพศ', max_length=50, blank=True)
    disability_type = models.CharField('ประเภทความพิการ', max_length=255, blank=True, db_index=True)
    phone = models.CharField('โทรศัพท์', max_length=80, blank=True)
    address = models.TextField('ที่อยู่', blank=True)
    house_no = models.CharField('เลขที่', max_length=50, blank=True)
    village_no = models.CharField('หมู่ที่', max_length=50, blank=True)
    village_name = models.CharField('หมู่บ้าน', max_length=150, blank=True)
    road = models.CharField('ถนน', max_length=150, blank=True)
    subdistrict = models.CharField('ตำบล', max_length=150, blank=True, db_index=True)
    district = models.CharField('อำเภอ', max_length=150, blank=True, db_index=True)
    province = models.CharField('จังหวัด', max_length=150, blank=True, db_index=True)
    postal_code = models.CharField('รหัสไปรษณีย์', max_length=10, blank=True)
    map_url = models.URLField('ลิงก์ Google Maps', max_length=500, blank=True)
    photo = models.ImageField('รูปถ่าย', upload_to='photos/', null=True, blank=True)
    notes = models.TextField('หมายเหตุ', blank=True)
    latitude = models.DecimalField('ละติจูด', max_digits=10, decimal_places=7, null=True, blank=True)
    longitude = models.DecimalField('ลองจิจูด', max_digits=10, decimal_places=7, null=True, blank=True)
    source_row = models.PositiveIntegerField(default=0)
    raw_data = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def full_name(self):
        return f'{self.prefix}{self.first_name} {self.last_name}'.strip()

    def __str__(self):
        return self.full_name


class MedicalCheck(models.Model):
    person = models.ForeignKey(PersonWithDisability, related_name='medical_checks', on_delete=models.CASCADE)
    check_date = models.DateField()
    detail = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-check_date', '-id']

    def __str__(self):
        return f'{self.person.full_name} - {self.check_date}'


class MedicalCheckPhoto(models.Model):
    medical_check = models.ForeignKey(MedicalCheck, related_name='photos', on_delete=models.CASCADE)
    image = models.ImageField(upload_to='check_photos/')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['id']
