require "bundler/setup"
require "dotenv/load"
require_relative "../db"
require "bcrypt"

EMAIL = ENV["USER_EMAIL"] || ENV["ADMIN_EMAIL"] || "admin@example.com"

user = DB.users.find(email: EMAIL, active: true).first
abort "User not found: #{EMAIL}" unless user
uid = user["_id"]

MAP_POS = {
  "adj." => "adjective",
  "n."   => "noun",
  "v."   => "verb"
}

WORDS = [
  ["Ephemeral",   "adj.", "短暫的、轉瞬即逝的", "Something that lasts for a very short time.", "The beauty of a sunset is ephemeral."],
  ["Mellifluous", "adj.", "聲音甜美的、悅耳的", "Having a smooth, rich and pleasant sound.", "She has a mellifluous voice that calms everyone."],
  ["Ubiquitous",  "adj.", "無所不在的", "Seeming to be everywhere at the same time.", "Smartphones have become a ubiquitous part of modern life."],
  ["Serendipity", "n.",   "意外發現新事物的能力或運氣", "The occurrence of events by chance in a happy way.", "Meeting my old friend on the street was a moment of pure serendipity."],
  ["Quixotic",    "adj.", "不切實際的、異想天開的", "Extremely idealistic; unrealistic and impractical.", "His quixotic dream of becoming a famous painter never came true."],
  ["Pernicious",  "adj.", "有害的、惡性的（隱微且逐漸）", "Having a harmful effect, especially in a gradual way.", "The pernicious effects of social media addiction are a growing concern."],
  ["Esoteric",    "adj.", "只有少數人懂的、深奧難懂的", "Intended for or understood by only a small number of people.", "The book was filled with esoteric philosophical concepts."],
  ["Panacea",     "n.",   "萬靈丹、萬全之策", "A remedy for all difficulties or diseases.", "There is no panacea for all of the world's problems."],
  ["Lassitude",   "n.",   "倦怠、無力", "A state of physical or mental weariness; lack of energy.", "A feeling of lassitude washed over him after the long journey."],
  ["Idiosyncrasy","n.",   "個人特有的習慣或怪癖", "A distinctive or peculiar feature of an individual.", "One of his idiosyncrasies is that he always counts his steps."]
]

def cambridge_url(headword)
  "https://dictionary.cambridge.org/dictionary/english/#{URI.encode_www_form_component(headword)}"
end

now = Time.now.utc
count = 0

WORDS.each do |head, pos_abbr, zh, en, ex1|
  pos = [MAP_POS[pos_abbr] || pos_abbr]
  doc = {
    user_id: uid,
    headword: head,
    headword_lower: head.downcase,
    first_letter: head[0]&.upcase&.gsub(/[^A-Z]/, "") || "#",
    pos: pos,
    definition_zh: zh,
    definition_en: en,
    definition: zh,
    example: ex1,
    example2: "",
    cambridge_url: cambridge_url(head),
    remembered: false,
    review_count: 0,
    created_at: now,
    updated_at: now
  }

  res = DB.words.update_one(
    { user_id: uid, headword_lower: head.downcase },
    { "$setOnInsert": doc },
    upsert: true
  )
  count += 1 if res.upserted_id
end

puts "Seed inserted #{count} new words for #{EMAIL}."
