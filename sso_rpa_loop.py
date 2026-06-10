# -*- coding: utf-8 -*-
import pandas as pd
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver import ActionChains
import time

def run_rpa_with_clear(excel_path, user, pw):
    try:
        print(f"กำลังอ่านไฟล์ Excel: {excel_path}")
        df = pd.read_excel(excel_path, sheet_name='รวมอื่นๆ')
        col_id = 'เลขผู้ประกันตน'
        col_claim = 'เลขที่รับแจ้ง'
        df = df.dropna(subset=[col_id, col_claim], how='all')
        print(f"พบข้อมูลทั้งหมด {len(df)} แถว")
    except Exception as e:
        print(f"Error reading Excel: {e}")
        return

    options = webdriver.ChromeOptions()
    options.add_experimental_option("detach", True)
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    wait = WebDriverWait(driver, 15)
    actions = ActionChains(driver)

    try:
        url = "https://appssocore.sso.go.th/benefit-web/order/payment"
        driver.get(url)
        
        print("กำลัง Login...")
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(user)
        wait.until(EC.presence_of_element_located((By.ID, "password"))).send_keys(pw)
        login_btn = wait.until(EC.element_to_be_clickable((By.ID, "kc-login")))
        driver.execute_script("arguments[0].click();", login_btn)
        
        time.sleep(8)

        for index, row in df.iterrows():
            id_card = str(row[col_id]).strip().replace('.0', '') if pd.notnull(row[col_id]) else ""
            claim_no = str(row[col_claim]).strip().replace('.0', '') if pd.notnull(row[col_claim]) else ""

            print(f"\n--- กำลังทำแถวที่ {index+1} ---")
            print(f"ค้นหา: เลขบัตร={id_card}, เลขรับแจ้ง={claim_no}")
            
            try:
                # 1. กรอกข้อมูลค้นหา
                id_field = wait.until(EC.presence_of_element_located((By.ID, "searchPaymentOrderForm_ssoNo")))
                id_field.clear()
                if id_card: id_field.send_keys(id_card)
                
                claim_field = wait.until(EC.presence_of_element_located((By.ID, "searchPaymentOrderForm_claimNo")))
                claim_field.clear()
                if claim_no: claim_field.send_keys(claim_no)
                
                # 2. กดปุ่มค้นหา
                search_btn = driver.find_element(By.CSS_SELECTOR, "button.ant-btn.button_primary__-\\+MUu")
                driver.execute_script("arguments[0].click();", search_btn)
                
                print("รอผลการค้นหา...")
                time.sleep(3)
                
                # 3. ตรวจสอบว่าเจอเลขรับแจ้งในตารางหรือไม่
                try:
                    claim_cell_xpath = f"//table//a[contains(text(), '{claim_no}')] | //table//span[contains(text(), '{claim_no}')] | //td[contains(text(), '{claim_no}')]"
                    claim_element = driver.find_element(By.XPATH, claim_cell_xpath)
                    
                    print(f"เจอเลขรับแจ้ง {claim_no} ในตารางแล้ว กำลังดับเบิ้ลคลิก...")
                    driver.execute_script("arguments[0].scrollIntoView(true);", claim_element)
                    time.sleep(0.5)
                    actions.double_click(claim_element).perform()
                    
                    print("ดับเบิ้ลคลิกเรียบร้อยแล้ว และหยุดตามคำสั่ง")
                    return 

                except Exception:
                    print(f"ไม่พบเลขรับแจ้ง {claim_no} กำลังกดปุ่ม 'ล้าง' และไปแถวถัดไป...")
                    # กดปุ่มล้าง (ปุ่มที่ 1 จากการ debug ครั้งก่อน)
                    clear_btn = driver.find_element(By.CSS_SELECTOR, "button.ant-btn.styles_cancelButton__iK2a1")
                    driver.execute_script("arguments[0].click();", clear_btn)
                    time.sleep(1) # รอให้หน้าจอเคลียร์ข้อมูล
                    continue 
                
            except Exception as e:
                print(f"เกิดข้อผิดพลาดในแถวนี้: {e}")
                continue

    except Exception as e:
        print(f"General Error: {e}")

if __name__ == "__main__":
    EXCEL_FILE = r"C:\RPA\temp_data.xlsx"
    USERNAME = "lthararat"
    PASSWORD = "Ro$e5299"
    run_rpa_with_clear(EXCEL_FILE, USERNAME, PASSWORD)
