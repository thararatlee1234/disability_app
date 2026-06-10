# Disability App (Django + Flutter)

โปรเจกต์ตัวอย่างสำหรับนำเข้าข้อมูลผู้ทุพพลภาพจาก Excel และใช้งานผ่าน API Django + แอป Flutter ที่รันได้ทั้ง Android, iOS และ Web

## โครงสร้าง
- `backend/` Django REST API
- `flutter_app/` Flutter client
- `setup_windows.bat` สคริปต์ติดตั้งโฟลเดอร์ที่ `C:\admin\disability_app`

## บัญชีเริ่มต้น
- Username: `Rose`
- Password: `260245`

## วิธีติดตั้งบน Windows
1. แตก ZIP นี้
2. คลิกขวา `setup_windows.bat` แล้ว Run as administrator
3. เข้าโฟลเดอร์ `C:\admin\disability_app\backend`
4. เปิด API: `run_backend.bat`
5. เข้าโฟลเดอร์ `C:\admin\disability_app\flutter_app`
6. เปิดแอป: `flutter run -d chrome` หรือ `flutter run` สำหรับ Android/iOS

## API หลัก
- `GET /api/persons/` รายชื่อทั้งหมด
- `GET /api/persons/?search=ชื่อ` ค้นหา
- `POST /api/import-excel/` อัปโหลด Excel เพื่อนำเข้าใหม่
- `GET /api/stats/` สรุปจำนวนตามจังหวัด/ตำบล/ประเภทความพิการ
- `POST /api/token/` Login เพื่อรับ JWT

## หมายเหตุ
ไฟล์ Excel ที่แนบมาใส่ไว้ที่ `backend/data/disabilities.xlsx` และจะถูกนำเข้าเมื่อรัน `python manage.py import_disabilities data/disabilities.xlsx`
