import json
from flask import Flask, jsonify
from flask_cors import CORS  # Recommended for Flutter web/emulator testing
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
import firebase_admin
from firebase_admin import credentials, firestore
from apscheduler.schedulers.background import BackgroundScheduler
import hashlib

cred = credentials.Certificate("fyp-pwd-firebase-adminsdk-fbsvc-3e36822cd1.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

def scrape_and_push_to_firebase():
    print("⏰ Periodic Task Started...")
    data = get_ndma_json_logic() 
    
    if isinstance(data, list):
        for item in data:
            # 1. Create a safe, unique ID
            # We use a hash of the title to ensure it's always a valid string
            clean_title = item['title'].strip()
            if not clean_title:
                continue # Skip if title is somehow empty
                
            # Create a unique ID using the first 20 chars + a hash of the full title
            # This avoids "even number of path elements" errors and illegal characters
            hash_object = hashlib.md5(clean_title.encode())
            doc_id = f"alert_{hash_object.hexdigest()[:12]}" 

            try:
                # 2. Reference the collection and the specific document
                doc_ref = db.collection("advisories").document(doc_id)
                
                # Check if it already exists to avoid unnecessary writes/notifications
                if not doc_ref.get().exists:
                    doc_ref.set(item)
                    print(f"🔥 Added to Firebase: {clean_title[:30]}...")
                    
                    # Trigger notification for the new item
                    # send_push_notification("New NDMA Advisory", clean_title)
                else:
                    print(f"✔️ Already exists: {clean_title[:30]}...")
                    
            except Exception as e:
                print(f"❌ Error saving document {doc_id}: {e}")

        print(f"✅ Firebase Sync Complete. Processed {len(data)} items.")

# 2. Schedule the task every 15 minutes
scheduler = BackgroundScheduler()
scheduler.add_job(func=scrape_and_push_to_firebase, trigger="interval", minutes=15)
scheduler.start()

app = Flask(__name__)
CORS(app) # Enable CORS for all routes

def get_ndma_json_logic():
    chrome_options = Options()
    chrome_options.add_argument("--headless=new") 
    chrome_options.add_argument("--window-size=1920,1080")
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    
    results = []

    try:
        print("Connecting to NDMA Advisories...")
        driver.get("https://www.ndma.gov.pk/advisories")

        wait = WebDriverWait(driver, 20)
        wait.until(EC.presence_of_element_located((By.PARTIAL_LINK_TEXT, "View")))

        xpath_query = "//h3 | //h4 | //p | //strong[string-length(text()) > 15] | //div[contains(@class, 'title')]"
        elements = driver.find_elements(By.XPATH, xpath_query)

        all_text_data = []
        for el in elements:
            text = el.text.strip()
            if text:
                all_text_data.append(text)

        # Logic to pair Title and Date from your raw output
        for i in range(1, len(all_text_data) - 1, 2):
            title = all_text_data[i].replace("View", "").strip()
            date = all_text_data[i+1].strip()

            # Filter out the footer/agency info
            if "lead agency" in title or "Copyright" in date or "Copyright" in title:
                continue
            
            if len(title) > 10:
                results.append({
                    "title": title,
                    "date": date,
                    "source": "NDMA Pakistan"
                })

        print(f"✅ Scraped {len(results)} items.")
        return results # CRITICAL: Returns data to the Flask route

    except Exception as e:
        print(f"❌ Error during scraping: {str(e)}")
        return {"error": str(e)}
    
    finally:
        driver.quit()

@app.route('/get-advisories', methods=['GET'])
def fetch_advisories():
    # Call the logic function and get the list
    data = get_ndma_json_logic() 
    return jsonify(data) # Flask converts the list to a JSON response

@app.route('/force-sync', methods=['GET'])
def force_sync():
    scrape_and_push_to_firebase()
    return jsonify({"status": "Manual sync completed and pushed to Firebase"})

if __name__ == "__main__":
    # Host 0.0.0.0 allows access from other devices (like your phone) on the same Wi-Fi
    app.run(host='0.0.0.0', port=5000, debug=True)