#!/usr/bin/env ruby
# frozen_string_literal: true

# 直接將 pt3-3000.json 的單字寫入 DB.words
# - 用 EMAIL 指定要寫入的帳號（ENV: USER_EMAIL 或 ADMIN_EMAIL）
# - 檔名固定 "pt3-300.json"，放在此腳本同一層或自行調整路徑
#
# 執行：
#   USER_EMAIL=you@example.com ruby dobby/import_words_from_json.rb
#docker compose run --rm -e USER_EMAIL=test@gmail.com web ruby -W0 dobby/import_words_from_json.rb

require "bundler/setup"
require "dotenv/load"
require "json"
require "uri"
require_relative "../db"

EMAIL = ENV["USER_EMAIL"] || ENV["ADMIN_EMAIL"] || "admin@example.com"
FILE  = File.expand_path("../pt3-3000.json", __FILE__)

abort "找不到檔案：#{FILE}" unless File.exist?(FILE)

def load_items(file)
  raw = File.read(file, mode: "r:BOM|UTF-8")
  obj = JSON.parse(raw)
  return obj if obj.is_a?(Array)
  return obj["words"] if obj.is_a?(Hash) && obj["words"].is_a?(Array)
  raise "pt3-300.json 結構錯誤：需為 JSON 陣列或 {\"words\":[...]} 兩種其一"
rescue JSON::ParserError => e
  raise "JSON 解析失敗：#{e.message}"
end

DB.ensure_indexes! if DB.respond_to?(:ensure_indexes!)

user = DB.users.find(email: EMAIL, active: true).first
abort "User not found: #{EMAIL}" unless user
uid = user["_id"]

# 正規化
MAP_POS = {
  "adj." => "adjective", "adj" => "adjective", "adjective" => "adjective",
  "n."   => "noun",      "n"   => "noun",      "noun"      => "noun",
  "v."   => "verb",      "v"   => "verb",      "verb"      => "verb",
  "adv"  => "adverb",    "adv."=> "adverb",    "adverb"    => "adverb"
}
POS_OPTIONS = %w[noun verb adjective adverb phrase preposition conjunction pronoun determiner number auxiliary interjection].freeze

def norm_pos(pos)
  arr = Array(pos).map { |p| p.to_s.strip.downcase }
  arr = [""] if arr.empty?
  arr.map { |p|
    mapped = MAP_POS[p] || p
    POS_OPTIONS.include?(mapped) ? mapped : nil
  }.compact.uniq
end

def cambridge_url(headword)
  "https://dictionary.cambridge.org/dictionary/english/#{URI.encode_www_form_component(headword)}"
end

def load_items(file)
  txt = File.read(file, mode: "r:BOM|UTF-8")
  obj = JSON.parse(txt)
  return obj if obj.is_a?(Array)
  return obj["words"] if obj.is_a?(Hash) && obj["words"].is_a?(Array)
  raise "pt3-300.json 結構錯誤：請提供 JSON 陣列或 {\"words\":[...]} 兩種其一"
end

items = load_items(FILE)
now = Time.now.utc
inserted = 0
updated  = 0

UPDATE_EXISTING = false

items.each_with_index do |row, i|
  head = row["headword"].to_s.strip
  if head.empty?
    warn "[#{i}] 略過：headword 不可為空"
    next
  end

  pos = norm_pos(row["pos"])
  zh  = row["definition_zh"].to_s
  zh  = row["definition"].to_s if zh.empty? && row.key?("definition") 
  en  = row["definition_en"].to_s
  ex1 = row["example"].to_s
  ex2 = row["example2"].to_s
  cam = row["cambridge_url"].to_s
  first_letter = head[0]&.upcase&.gsub(/[^A-Z]/, "") || "#"

  base_doc = {
    user_id: uid,
    headword: head,
    headword_lower: head.downcase,
    first_letter: first_letter,
    pos: pos,
    definition_zh: zh,
    definition_en: en,
    definition: zh,
    example: ex1,
    example2: ex2,
    cambridge_url: cam.empty? ? cambridge_url(head) : cam,
    remembered: false,
    review_count: 0,
    updated_at: now
  }

  selector = { user_id: uid, headword_lower: head.downcase }

  if UPDATE_EXISTING
    doc = base_doc.merge(created_at: now)
    res = DB.words.update_one(selector,
                              { "$set" => doc, "$setOnInsert" => { created_at: now } },
                              upsert: true)
    if res.upserted_id then inserted += 1 else updated += (res.modified_count || 0) end
  else
    doc = base_doc.merge(created_at: now)
    res = DB.words.update_one(selector,
                              { "$setOnInsert" => doc },
                              upsert: true)
    inserted += 1 if res.upserted_id
  end
end

puts "Done for #{EMAIL}. Inserted: #{inserted}, Updated: #{updated}, Total input: #{items.size}"
