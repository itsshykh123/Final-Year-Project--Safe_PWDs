# SAFE-PWDs: Inclusive Disaster Management System 🚨

**SAFE-PWDs** is a specialized disaster management application designed to bridge the gap in emergency communications for Persons with Disabilities (PWDs). By utilizing real-time web scraping and multimodal feedback, the system ensures that life-saving information reaches everyone, regardless of their sensory impairments.

---

## 🛠 Features

### ♿ Accessibility First
* **Blind Mode:** Automated **Text-to-Speech (TTS)** triggers. When an alert hits the DB, the phone speaks the danger level and instructions.
* **Deaf Mode:** High-intensity **vibration patterns** and persistent visual **Material Banners** that don't disappear until acknowledged.
* **Both:** Simultaneous audio-visual-haptic feedback for maximum safety.

### 🤖 Intelligent Backend
* **Live Scraper:** Python script using Selenium/BeautifulSoup to monitor NDMA advisories.
* **Auto-Sync:** Background scheduler pushes new data to Firebase Firestore every 15 minutes.
* **Duplicate Prevention:** Title-based hashing to ensure the database stays clean and users aren't spammed.

---

## 🏗 System Architecture



1.  **Extraction:** Python script scrapes the National Disaster Management Authority (NDMA) website.
2.  **Storage:** Data is cleaned and pushed to **Firebase Firestore**.
3.  **Transmission:** **Firebase Cloud Messaging (FCM)** sends push notifications for high-risk events.
4.  **Reception:** Flutter app listens to the Firestore stream and triggers accessibility services based on `user_mode`.

---

## 💻 Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Mobile App** | Flutter (Dart) |
| **Backend** | Python (Flask) |
| **Database** | Firebase Firestore |
| **Scraper** | Selenium / Undetected Chromedriver |
| **Speech Engine** | Flutter TTS |
| **Haptics** | Vibration / HapticFeedback API |

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (v3.0+)
* Python 3.12+
* Firebase Service Account Key (`serviceAccountKey.json`)

### Installation

1. **Clone the repo**
   ```bash
   git clone [https://github.com/yourusername/safe-pwds.git](https://github.com/yourusername/safe-pwds.git)