#!/usr/bin/env ruby
# frozen_string_literal: true

# 既有使用者的 word_lang 預設為 "en"
#
# 用法：
#   # 全部回填
#   ruby dobby/backfill_word_lang.rb
#
#   # 只回填某一位使用者
#   USER_EMAIL=you@example.com ruby dobby/backfill_word_lang.rb
#
# Docker Compose 範例：
#   docker compose run --rm -e USER_EMAIL=test@test.com web ruby -W0 dobby/backfill_word_lang.rb

require "bundler/setup"
require "dotenv/load"
require_relative "../db"

EMAIL = ENV["USER_EMAIL"]&.strip

DB.ensure_indexes! if DB.respond_to?(:ensure_indexes!)

def filter_for_missing
  {
    "$or" => [
      { word_lang: { "$exists": false } },
      { word_lang: nil },
      { word_lang: "" }
    ]
  }
end

begin
  scope = filter_for_missing

  if EMAIL && !EMAIL.empty?
    user = DB.users.find(email: EMAIL).projection(_id: 1).first
    abort "User not found: #{EMAIL}" unless user
    scope = scope.merge({ email: EMAIL })
  end

  result = DB.users.update_many(scope, { "$set" => { word_lang: "en" } })

  target_desc = EMAIL && !EMAIL.empty? ? EMAIL : "ALL USERS"
  puts "[OK] backfill word_lang='en' for #{target_desc}"
  puts "matched=#{result.matched_count}, modified=#{result.modified_count}"

rescue => e
  warn "[ERR] #{e.class}: #{e.message}"
  exit 1
end
