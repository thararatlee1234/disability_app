# การอัปเดต Backend บน PythonAnywhere

เพื่อให้การแก้ไขปัญหา (เช่น Error 400) มีผลบน Server คุณต้องทำการอัปเดตโค้ดดังนี้:

### 1. อัปโหลดไฟล์ที่แก้ไข
หากคุณใช้ Git ให้ทำการ `commit` และ `push` โค้ดจากเครื่องนี้ขึ้นไปก่อน:
```bash
git add .
git commit -m "Fix coordinate precision and 400 error"
git push
```

### 2. รันสคริปต์อัปเดตบน PythonAnywhere
เปิด **Bash Console** บน PythonAnywhere แล้วเข้าไปที่โฟลเดอร์ของโปรเจกต์ (`disability_app/backend`) จากนั้นรันคำสั่ง:
```bash
chmod +x update_pa.sh
./update_pa.sh
```

**สิ่งที่สคริปต์จะทำ:**
*   ดึงโค้ดล่าสุด (`git pull`)
*   อัปเดตไลบรารี (`pip install`)
*   อัปเดตฐานข้อมูล (`migrate`)
*   รวบรวมไฟล์ Static (`collectstatic`)
*   รีโหลด Web App ให้โดยอัตโนมัติ

### 3. ตรวจสอบหน้าเว็บ
หลังจากรันสคริปต์เสร็จ ให้ลองทดสอบการปักหมุดในมือถืออีกครั้งครับ
