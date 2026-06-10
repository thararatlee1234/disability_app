# -*- coding: utf-8 -*-
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

def inspect_button(user, pw):
    options = webdriver.ChromeOptions()
    options.add_argument("--headless")
    options.add_argument("--window-size=1920,1080")
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    
    try:
        url = "https://appssocore.sso.go.th/benefit-web/order/payment"
        driver.get(url)
        wait = WebDriverWait(driver, 20)
        
        # Login
        wait.until(EC.presence_of_element_located((By.ID, "username"))).send_keys(user)
        wait.until(EC.presence_of_element_located((By.ID, "password"))).send_keys(pw)
        login_btn = wait.until(EC.element_to_be_clickable((By.ID, "kc-login")))
        driver.execute_script("arguments[0].click();", login_btn)
        
        time.sleep(10)
        
        # Find all clickable elements that contain 'ค้นหา'
        print("Searching for elements with text 'ค้นหา'...")
        elements = driver.find_elements(By.XPATH, "//*[contains(text(), 'ค้นหา')]")
        for idx, el in enumerate(elements):
            print(f"[{idx}] Tag: {el.tag_name}, Text: '{el.text}', ID: '{el.get_attribute('id')}', Class: '{el.get_attribute('class')}'")

    except Exception as e:
        print("Error:", e)
    finally:
        driver.quit()

if __name__ == "__main__":
    inspect_button("lthararat", "Ro$e5299")
