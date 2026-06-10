# -*- coding: utf-8 -*-
import pandas as pd
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
import time

def run_single_search(excel_path, user, pw):
    try:
        df = pd.read_excel(excel_path, sheet_name='รวมอื่นๆ')
        col_id = 'เลขผู้ประกันตน'
        col_claim = 'เลขที่รับแจ้ง'
        
        row = df.iloc[0]
        id_card = str(row[col_id]).strip().replace('.0', '') if pd.notnull(row[col_id]) else ""
        claim_no = str(row[col_claim]).strip().replace('.0', '') if pd.notnull(row[col_claim]) else ""
        print(f"ข้อมูลที่จะค้นหา: เลขบัตร={id_card}, เลขรับแจ้ง={claim_no}")
    except Exception as e:
        print(f"Error reading Excel: {e}")
        return

    options = webdriver.ChromeOptions()
    options.add_experimental_option("detach", True)
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    wait = WebDriverWait(driver, 30)

    try:
        url = "https://appssocore.sso.go.th/benefit-web/order/payment"
        driver.get(url)
        
        # Login
        print("กำลัง Login...")
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(user)
        wait.until(EC.presence_of_element_located((By.ID, "password"))).send_keys(pw)
        login_btn = wait.until(EC.element_to_be_clickable((By.ID, "kc-login")))
        driver.execute_script("arguments[0].click();", login_btn)
        
        time.sleep(10) # ให้เวลาหน้าโหลดเต็มที่

        print("กำลังกรอกข้อมูล...")
        id_field = wait.until(EC.presence_of_element_located((By.ID, "searchPaymentOrderForm_ssoNo")))
        id_field.clear()
        id_field.send_keys(id_card)
        
        claim_field = wait.until(EC.presence_of_element_located((By.ID, "searchPaymentOrderForm_claimNo")))
        claim_field.clear()
        claim_field.send_keys(claim_no)
        
        print("กำลังกดปุ่มค้นหาด้วย CSS Selector เฉพาะเจาะจง...")
        # จากการ debug HTML: ปุ่มค้นหาใช้ class button_primary__-+MUu และมีข้อความ 'ค้นหา'
        # เราจะลองหลายวิธีพร้อมกัน
        
        try:
            # วิธีที่ 1: คลิกที่ปุ่มโดยตรงโดยใช้ CSS class ที่เป็นเอกลักษณ์
            search_btn = driver.find_element(By.CSS_SELECTOR, "button.ant-btn.button_primary__-\\+MUu")
            driver.execute_script("arguments[0].scrollIntoView(true);", search_btn)
            time.sleep(1)
            driver.execute_script("arguments[0].click();", search_btn)
            print("กดปุ่มสำเร็จด้วย CSS Selector (button_primary)")
        except:
            try:
                # วิธีที่ 2: ถ้าวิธีแรกไม่ได้ผล ให้ลองกด Enter ที่ช่องกรอกข้อมูล (มักจะใช้ได้กับฟอร์มสมัยใหม่)
                claim_field.send_keys(Keys.ENTER)
                print("ส่งคำสั่งค้นหาด้วยการกด ENTER ที่ช่องเลขรับแจ้ง")
            except:
                # วิธีที่ 3: ใช้ XPath ที่แม่นยำที่สุดจาก HTML structure
                btn_xpath = "//button[span[text()='ค้นหา']]"
                btn = driver.find_element(By.XPATH, btn_xpath)
                driver.execute_script("arguments[0].click();", btn)
                print("กดปุ่มสำเร็จด้วย XPath (//button[span[text()='ค้นหา']])")
        
        print("หยุดตามคำสั่ง (Browser ยังเปิดอยู่)")

    except Exception as e:
        print(f"เกิดข้อผิดพลาด: {e}")

if __name__ == "__main__":
    EXCEL_FILE = r"C:\RPA\temp_data.xlsx"
    USERNAME = "lthararat"
    PASSWORD = "Ro$e5299"
    run_single_search(EXCEL_FILE, USERNAME, PASSWORD)
