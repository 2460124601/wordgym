
# Wordgym

---

## English

G'day! Wordgym is an open-source vocab learning and management app, built with Sinatra and MongoDB.

It's designed to be simple, flexible, and a bit of fun for anyone wanting to boost their word power.

**Note:** The app interface is currently only available in Chinese(TC). We're thinking about adding multi-language support in the future!

### Features
- Supports English, Japanese, and Dutch (more to come!)
- Organise words by category, mark as remembered, and add your own notes
- User registration, login, password reset, and email confirmation
- Admin dashboard for user and invite code management
- Random quiz mode to keep you on your toes
- Easy Docker deployment

### Tech Stack
- Backend: Ruby (Sinatra)
- Frontend: HTML, CSS, JS
- Database: MongoDB

### Quick Start
```bash
# 1. Install dependencies
bundle install

# 2. Set up your environment
cp .env.example .env
# Edit .env with your own settings

# 3. Fire up the server
ruby app.rb
# Or use Docker if that's your thing
# Use dobby/seed_admin.rb to create your first admin
```

### Project Structure (Simplified)
```
wordgym/
├── app.rb            # Main app entry
├── config/           # Server configs
├── db.rb             # MongoDB connection
├── dobby/            # Scripts (admin seed, import, etc)
├── public/           # Static files (css, js, icons)
├── routes/           # Sinatra route files
├── views/            # ERB templates
├── helpers/          # Auth helpers
├── Dockerfile, docker-compose.yml
├── .env, .gitignore
```

### Notes
- Started as a personal vocab tracker for PTE prep, so some bits are a bit rough around the edges (especially the admin UI and CSS!).
- Chose Sinatra for its light weight, and MongoDB for flexibility with different languages.
- English and Dutch are natively supported; Japanese is experimental (with a bit of help from GPT!).
- The speech feature is a hacky Google TTS call—if you have a Google Cloud account, best to switch to the official API.
- Accessibility and i18n are on the roadmap.
- If you spot a bug or have a suggestion, open an issue or PR—cheers!

### Demo Account
https://wordgym.cc
Email: tom@wordgym.cc
Password: 31Vkuqmo9ZZY

### License
MIT License

---

## 中文版

Wordgym（沒錯是諧音梗 xD）是一個開源的單字學習與管理平台，基於 Sinatra 框架與 MongoDB。

### 特色
- 支援英文、日文、荷蘭文（未來會增加更多語言）
- 單字分類、標記、記憶狀態
- 使用者註冊、登入、忘記密碼、Email 驗證
- 管理員後台：帳號、邀請碼、權限設定
- Quiz 隨機單字測驗
- Docker 部署支援

### 技術棧
- 後端：Ruby（Sinatra）
- 前端：HTML、CSS、JS
- 資料庫：MongoDB

### 安裝
```bash
# 1. 安裝依賴
bundle install

# 2. 設定環境變數
cp .env.example .env
# 編輯 .env 檔案

# 3. 啟動伺服器
ruby app.rb
# 或使用 Docker
# 使用 dobby/seed_admin.rb 可以建立首位管理員
```

### 目錄結構（簡化版）
```
wordgym/
├── app.rb            # 主程式入口
├── config/           # 設定檔
├── db.rb             # MongoDB 連線
├── dobby/            # 輔助腳本
├── public/           # 靜態資源
├── routes/           # 路由
├── views/            # ERB
├── helpers/          # 認證輔助
├── Dockerfile, docker-compose.yml
├── .env, .gitignore
```

### 備註
- 本專案最初為個人 PTE 單字記錄工具，介面與功能較為簡單，後續逐步擴充，目前部分設計較為倉促，如：CSS 樣式...，正在逐步更新中。
- 選用 Sinatra 輕量框架與 MongoDB，方便多語種彈性擴展。
- 英文、荷蘭文為原生支援（都可在 ASCII 範圍內），日文為實驗性加入（感謝 GPT 協助日文方面工作）。
- 語音功能為 Google TTS 非官方串接，建議有大量需求者改用官方 API，較為穩妥。
- 無障礙與多語系功能正在規劃中。
- 歡迎 issue 或 PR！

### 測試帳號
https://wordgym.cc
帳號：tom@wordgym.cc
密碼：31Vkuqmo9ZZY

### 授權
MIT License