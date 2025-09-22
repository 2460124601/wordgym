require "mongo"

module DB
  def self.client
    @client ||= Mongo::Client.new(
      ENV.fetch("MONGO_URL"),
      server_api: { version: "1" },
      server_selection_timeout: 5,
      connect_timeout: 5,
      socket_timeout: 5
    )
  end

  def self.db = client.use(ENV.fetch("MONGO_DB"))

  # collections
  def self.users      = db[:users]
  def self.words      = db[:words]
  def self.categories = db[:categories]
  def self.settings   = db[:settings]
  def self.invites    = db[:invites]

  def self.ensure_indexes!
    safe_create_index = lambda do |col, keys, opts = {}|
      begin
        col.indexes.create_one(keys, **opts)
      rescue Mongo::Error::OperationFailure => e
        code = e.respond_to?(:error_code) ? e.error_code : nil
        if code == 85 || code == 86
          warn "[indexes] skip #{col.name} #{keys.inspect} #{opts.inspect} (#{code})"
        else
          raise
        end
      end
    end

    # users
    safe_create_index.call(users, { email: 1 }, unique: true)

    # words
    safe_create_index.call(words, { user_id: 1, headword_lower: 1 }, unique: true)
    safe_create_index.call(words, { user_id: 1, first_letter: 1 })
    safe_create_index.call(words, { user_id: 1, remembered: 1 })
    safe_create_index.call(words, { user_id: 1, category_ids: 1 })
    safe_create_index.call(words, { user_id: 1, reading_row: 1 })
    safe_create_index.call(words, { user_id: 1, reading_ja: 1 })

    # categories
    safe_create_index.call(categories, { user_id: 1, name: 1 }, unique: true)
    safe_create_index.call(categories, { user_id: 1, created_at: 1 })

    # settings / invites
    safe_create_index.call(settings, { key: 1 },  unique: true)
    safe_create_index.call(invites,  { code: 1 }, unique: true)
    safe_create_index.call(invites,  { active: 1 })
    safe_create_index.call(invites,  { created_at: -1 })
  end
end
