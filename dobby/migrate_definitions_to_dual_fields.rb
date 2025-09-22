require "bundler/setup"
require "dotenv/load"
require_relative "../db"

n = 0
DB.words.find({ "$or" => [
  { definition_zh: { "$exists": false } },
  { definition_zh: "" }
], definition: { "$exists": true, "$ne": "" } }).each do |w|
  DB.words.update_one({ _id: w["_id"] }, {
    "$set": {
      definition_zh: w["definition"],
      updated_at: Time.now.utc
    }
  })
  n += 1
end
puts "Migrated #{n} documents."
