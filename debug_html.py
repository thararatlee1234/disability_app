# -*- coding: utf-8 -*-
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time

def debug_search_area(user, pw):
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
        
        # Look for the container that has the inputs
        print("Finding search form container...")
        container = driver.find_element(By.XPATH, "//div[contains(@class, 'card') or contains(@class, 'form')]")
        print("HTML of search area:")
        # Find all buttons in the page and print their full HTML
        buttons = driver.find_elements(By.TAG_NAME, "button")
        for idx, btn in enumerate(buttons):
            print(f"Button {idx} HTML: {btn.get_attribute('outerHTML')}")
            
    except Exception as e:
        print("Error:", e)
    finally:
        driver.quit()

if __name__ == "__main__":
    debug_search_area("lthararat", "Ro$e5299")
