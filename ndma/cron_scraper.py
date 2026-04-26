import os
import json
import hashlib
import firebase_admin
from firebase_admin import credentials, firestore
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

def setup_firebase():
    # Looks for a GitHub Secret or Environment Variable named FIREBASE_CONFIG
    fb_config_str = os.environ.get('FIREBASE_CONFIG')
    
    if not fb_config_str:
        # Fallback for local testing: looks for your local JSON file
        print("🏠 Running locally with JSON file...")
        cred = credentials.Certificate("fyp-pwd-firebase-adminsdk-fbsvc-d1c1a020cb.json")
    else:
            # Running on GitHub Actions
            print("☁️ Running on GitHub with Secrets...")
            try:
                fb_config_dict = json.loads(fb_config_str)
                print(f"🔑 Keys found for project: {fb_config_dict.get('project_id')}")
                cred = credentials.Certificate(fb_config_dict)
            except Exception as e:
                print(f"❌ JSON Parsing Error: {e}")
                # This will show you if the secret is cut off or malformed
                print(f"First 20 chars of secret: {fb_config_str[:20]}") 
                raise
    
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    return firestore.client()

def get_ndma_data():
    chrome_options = Options()
    chrome_options.add_argument("--headless=new") 
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--window-size=1920,1080")

    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    results = []

    try:
        print("📡 Connecting to NDMA...")
        driver.get("https://www.ndma.gov.pk/advisories")
        wait = WebDriverWait(driver, 20)
        wait.until(EC.presence_of_element_located((By.PARTIAL_LINK_TEXT, "View")))

        xpath_query = "//h3 | //h4 | //p | //strong[string-length(text()) > 15] | //div[contains(@class, 'title')]"
        elements = driver.find_elements(By.XPATH, xpath_query)

        all_text_data = [el.text.strip() for el in elements if el.text.strip()]

        for i in range(1, len(all_text_data) - 1, 2):
            title = all_text_data[i].replace("View", "").strip()
            date = all_text_data[i+1].strip()

            if "lead agency" in title.lower() or "copyright" in title.lower() or len(title) < 10:
                continue
            
            results.append({
                "title": title,
                "date": date,
                "source": "NDMA Pakistan"
            })

        print(f"✅ Scraped {len(results)} items.")
        return results

    except Exception as e:
        print(f"❌ Scraper Error: {e}")
        return []
    finally:
        driver.quit()

def run_sync():
    db = setup_firebase()
    data = get_ndma_data()

    if not data:
        print("⚠️ No data found to sync.")
        return

    for item in data:
        clean_title = item['title'].strip()
        # Create a unique ID so we don't duplicate alerts
        hash_id = hashlib.md5(clean_title.encode()).hexdigest()[:12]
        doc_id = f"alert_{hash_id}"

        doc_ref = db.collection("advisories").document(doc_id)
        
        if not doc_ref.get().exists:
            doc_ref.set(item)
            print(f"🔥 Added: {clean_title[:40]}...")
        else:
            print(f"✔️ Exists: {clean_title[:40]}...")

if __name__ == "__main__":
    run_sync()