# -*- coding: utf-8 -*-
import pandas as pd
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import os

def run_rpa(excel_path, user, pw):
    try:
        print(f"Reading Excel: {excel_path}")
        df = pd.read_excel(excel_path, sheet_name='รวมอื่นๆ')
        
        # Mapping based on inspection
        col_id = 'เลขผู้ประกันตน'
        col_claim = 'เลขที่รับแจ้ง'
        
        if col_id not in df.columns or col_claim not in df.columns:
            print(f"Error: Required columns not found.")
            print(f"Available columns: {df.columns.tolist()}")
            return
            
        df = df.dropna(subset=[col_id, col_claim], how='all')
        print(f"Found {len(df)} rows to process.")
    except Exception as e:
        print(f"Error reading Excel: {e}")
        return

    options = webdriver.ChromeOptions()
    options.add_experimental_option("detach", True)
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    wait = WebDriverWait(driver, 15)

    try:
        url = "https://appssocore.sso.go.th/benefit-web/order/payment"
        driver.get(url)
        
        print("Logging in...")
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(user)
        wait.until(EC.presence_of_element_located((By.ID, "password"))).send_keys(pw)
        login_btn = wait.until(EC.element_to_be_clickable((By.ID, "kc-login")))
        driver.execute_script("arguments[0].click();", login_btn)
        
        time.sleep(5)

        for index, row in df.iterrows():
            id_card = ""
            if pd.notnull(row[col_id]):
                id_card = str(row[col_id]).strip()
                if id_card.endswith('.0'): id_card = id_card[:-2]
            
            claim_no = ""
            if pd.notnull(row[col_claim]):
                claim_no = str(row[col_claim]).strip()
                if claim_no.endswith('.0'): claim_no = claim_no[:-2]

            print(f"Processing Row {index+1}: ID={id_card}, Claim={claim_no}")
            
            try:
                id_field = wait.until(EC.presence_of_element_located((By.ID, "searchPaymentOrderForm_ssoNo")))
                id_field.clear()
                if id_card:
                    id_field.send_keys(id_card)
                
                claim_field = wait.until(EC.presence_of_element_located((By.ID, "searchPaymentOrderForm_claimNo")))
                claim_field.clear()
                if claim_no:
                    claim_field.send_keys(claim_no)
                
                search_btn = wait.until(EC.element_to_be_clickable((By.XPATH, "//button[contains(text(), 'ค้นหา')]")))
                driver.execute_script("arguments[0].click();", search_btn)
                
                time.sleep(3)
                
            except Exception as e:
                print(f"Error processing row {index+1}: {e}")

        print("RPA Task Completed.")

    except Exception as e:
        print(f"General Error: {e}")

if __name__ == "__main__":
    EXCEL_FILE = r"C:\RPA\temp_data.xlsx"
    USERNAME = "lthararat"
    PASSWORD = "Ro$e5299"
    run_rpa(EXCEL_FILE, USERNAME, PASSWORD)
