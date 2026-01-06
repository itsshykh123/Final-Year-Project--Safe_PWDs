import json
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

def get_ndma_json():
    chrome_options = Options()
    chrome_options.add_argument("--headless=new") 
    chrome_options.add_argument("--window-size=1920,1080")
    chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chrome_options)
    
    # List to store our JSON objects
    results = []

    try:
        print("Connecting to NDMA Advisories...")
        driver.get("https://www.ndma.gov.pk/advisories")

        wait = WebDriverWait(driver, 20)
        # Wait for the view buttons to be sure content is loaded
        wait.until(EC.presence_of_element_located((By.PARTIAL_LINK_TEXT, "View")))

        # 1. Target headings based on your previous logic
        xpath_query = "//h3 | //h4 | //p | //strong[string-length(text()) > 15] | //div[contains(@class, 'title')]"
        elements = driver.find_elements(By.XPATH, xpath_query)

        all_text_data = []
        for el in elements:
            text = el.text.strip()
            if text:
                all_text_data.append(text)

        # 2. Iterate through the collected text in pairs
        # We start from index 1 (the first actual title in your raw output) 
        # to skip the 'Advisories' header
        for i in range(1, len(all_text_data) - 1, 2):
            title = all_text_data[i].replace("View", "").strip()
            date = all_text_data[i+1].strip()

            # --- SKIP LOGIC ---
            # We skip the entry if the title is about the agency or if the date contains "Copyright"
            if "lead agency" in title or "Copyright" in date:
                continue
            
            # Filter out the footer/copyright text
            if "Copyright" not in title and len(title) > 10:
                results.append({
                    "title": title,
                    "date": date,
                    "source": "NDMA Pakistan"
                })

        # 3. Convert to JSON
        json_data = json.dumps(results, indent=4)
        print("\n--- JSON OUTPUT ---")
        print(json_data)

        # Optional: Save to a file
        with open('advisories.json', 'w') as f:
            f.write(json_data)
        print(f"\n✅ Successfully saved {len(results)} titles to advisories.json")

    except Exception as e:
        print(f"❌ Error: {str(e)}")
    
    finally:
        driver.quit()

if __name__ == "__main__":
    get_ndma_json()