# 使用方式：
#   bundle exec ruby dobby/seed_admin.rb
# 需設定 .env 或環境變數 ADMIN_EMAIL / ADMIN_PASSWORD

require "bundler/setup"
require "dotenv/load"
require_relative "../db"
require "bcrypt"

email = ENV.fetch("ADMIN_EMAIL")
password = ENV.fetch("ADMIN_PASSWORD")

doc = {
  email: email.strip.downcase,
  password_digest: BCrypt::Password.create(password),
  is_admin: true,
  active: true,
  created_at: Time.now.utc,
  updated_at: Time.now.utc
}

begin
  DB.users.insert_one(doc)
  puts "Admin created: #{email}"
rescue Mongo::Error::OperationFailure => e
  puts " #{e.class}: #{e.message}"
end

# docker compose run --rm web bundle exec ruby scripts/seed_admin.rb

