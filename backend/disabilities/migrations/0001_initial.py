# Generated for project scaffold
from django.db import migrations, models

class Migration(migrations.Migration):
    initial = True
    dependencies = []
    operations = [
        migrations.CreateModel(
            name='PersonWithDisability',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('citizen_id', models.CharField(blank=True, db_index=True, max_length=32, verbose_name='เลขบัตรประชาชน')),
                ('prefix', models.CharField(blank=True, max_length=50, verbose_name='คำนำหน้า')),
                ('first_name', models.CharField(db_index=True, max_length=150, verbose_name='ชื่อ')),
                ('last_name', models.CharField(db_index=True, max_length=150, verbose_name='นามสกุล')),
                ('gender', models.CharField(blank=True, max_length=50, verbose_name='เพศ')),
                ('disability_type', models.CharField(blank=True, db_index=True, max_length=255, verbose_name='ประเภทความพิการ')),
                ('phone', models.CharField(blank=True, max_length=80, verbose_name='โทรศัพท์')),
                ('address', models.TextField(blank=True, verbose_name='ที่อยู่')),
                ('subdistrict', models.CharField(blank=True, db_index=True, max_length=150, verbose_name='ตำบล')),
                ('district', models.CharField(blank=True, db_index=True, max_length=150, verbose_name='อำเภอ')),
                ('province', models.CharField(blank=True, db_index=True, max_length=150, verbose_name='จังหวัด')),
                ('latitude', models.DecimalField(blank=True, decimal_places=7, max_digits=10, null=True, verbose_name='ละติจูด')),
                ('longitude', models.DecimalField(blank=True, decimal_places=7, max_digits=10, null=True, verbose_name='ลองจิจูด')),
                ('source_row', models.PositiveIntegerField(default=0)),
                ('raw_data', models.JSONField(blank=True, default=dict)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
        ),
    ]
