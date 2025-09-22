require "sinatra/base"
require "sinatra/json"
require "sinatra/namespace"
require "dotenv/load"
require "net/http"
require "uri"
require "base64"
require "securerandom"
require "net/smtp"

require_relative "./db"
require_relative "./helpers/auth_helpers"

class Wordgym < Sinatra::Base
  helpers Sinatra::JSON
  helpers AuthHelpers
  register Sinatra::Namespace

  use Rack::Session::Cookie,
      key: "vocab.sid",
      path: "/",
      same_site: :lax,
      secure: false,
      httponly: true,
      expire_after: 365*24*60*60,
      secret: ENV.fetch("SESSION_SECRET")

  use Rack::Protection, except: [:json_csrf, :http_origin, :host_authorization]

  configure :development do
    require "sinatra/reloader"
    register Sinatra::Reloader
    also_reload "lib/**/*.rb"
    set :static_cache_control, [:public, max_age: 0]
  end

  configure do
    DB.ensure_indexes! if DB.respond_to?(:ensure_indexes!)
    set :erb, escape_html: true
    set :allow_open_signup, ENV.fetch("ALLOW_OPEN_SIGNUP", "false") == "true"
    set :static, true
    set :public_folder, File.expand_path("../public", __FILE__)
    set :views,         File.expand_path("../views",  __FILE__)
    set :port, ENV.fetch("PORT", 9292)
    set :bind, "0.0.0.0"
  end
  unless defined?(Wordgym::LANG_OPTIONS)
    LANG_OPTIONS = {
      "en" => { label: "English",    tts: "en" },
      "nl" => { label: "Nederlands", tts: "nl" },
      "ja" => { label: "日本語",       tts: "ja" }
    }.freeze
  end


  def user_word_lang
    v = (current_user && current_user["word_lang"]).to_s
    return "en" if v.empty? || !LANG_OPTIONS.key?(v)
    v
  end

  def resolve_tts_lang(param_tl)
    tl = param_tl.to_s.strip
    allow = LANG_OPTIONS.values.map { |h| h[:tts] }.compact.uniq
    return tl if allow.include?(tl)
    LANG_OPTIONS[user_word_lang][:tts]
  end
  def ja_normalize_kana(s)
    t = s.to_s.strip
    return "" if t.empty?
    t = t.tr("ァ-ン", "ぁ-ん")
    t = t.gsub(/[ー・\s]/, "")
    t = t.sub(/\Aっ+/, "")
    t = t.tr("ぁぃぅぇぉゃゅょゎ", "あいうえおやゆよわ")
    t
  end

  unless defined?(Wordgym::ROW_MAP)
    ROW_MAP = {
      "あ"=>"あ","い"=>"あ","う"=>"あ","え"=>"あ","お"=>"あ",
      "か"=>"か","き"=>"か","く"=>"か","け"=>"か","こ"=>"か",
      "さ"=>"さ","し"=>"さ","す"=>"さ","せ"=>"さ","そ"=>"さ",
      "た"=>"た","ち"=>"た","つ"=>"た","て"=>"た","と"=>"た",
      "な"=>"な","に"=>"な","ぬ"=>"な","ね"=>"な","の"=>"な",
      "は"=>"は","ひ"=>"は","ふ"=>"は","へ"=>"は","ほ"=>"は",
      "ま"=>"ま","み"=>"ま","む"=>"ま","め"=>"ま","も"=>"ま",
      "や"=>"や","ゆ"=>"や","よ"=>"や",
      "ら"=>"ら","り"=>"ら","る"=>"ら","れ"=>"ら","ろ"=>"ら",
      "わ"=>"わ","ゐ"=>"わ","ゑ"=>"わ","を"=>"わ",
      "ん"=>"ん"
    }.freeze
  end

  def ja_row_key(reading_ja)
    s = ja_normalize_kana(reading_ja)
    return "#" if s.empty?
    ROW_MAP[s[0]] || "#"
  end

  def latin_initial(str)
    ch = str.to_s.strip[0]
    return "#" unless ch
    s = ch.upcase.gsub(/[^A-Z]/, "")
    s.empty? ? "#" : s
  end

  unless defined?(Wordgym::POS_OPTIONS)
    POS_OPTIONS = %w[
      noun verb adjective adverb phrase preposition conjunction
      pronoun determiner number auxiliary interjection
    ].freeze
  end

  unless defined?(Wordgym::LANG_OPTIONS)
    LANG_OPTIONS = {
      "en" => { label: "English",    tts: "en" },
      "nl" => { label: "Nederlands", tts: "nl" },
      "ja" => { label: "日本語",       tts: "ja" }
    }.freeze
  end




  def auth_settings
    @auth_settings ||= begin
                         doc = DB.settings.find(key: "auth").first || {}
                         {
                           enable_login:     (doc["enable_login"].nil?  ? ENV.fetch("ENABLE_LOGIN", "true")  == "true" : !!doc["enable_login"]),
                           enable_register:  (doc["enable_register"].nil? ? ENV.fetch("ENABLE_REGISTER", "false") == "true" : !!doc["enable_register"]),
                           require_invite:   (doc["require_invite"].nil? ? ENV.fetch("REQUIRE_INVITE", "false") == "true" : !!doc["require_invite"]),
                           require_captcha:  (doc["require_captcha"].nil? ? true : !!doc["require_captcha"]),
                           confirm_by_email: (doc["confirm_by_email"].nil? ? ENV.fetch("CONFIRM_BY_EMAIL", "true") == "true" : !!doc["confirm_by_email"]),
                         }
                       end
  end
  def arr_oids(input)
    items = case input
            when Array then input
            when String then input.split(",")
            else Array(input)
            end
    items.map { |s| oid(s) rescue nil }.compact.uniq
  end
  def user_word_lang
    v = (current_user && current_user["word_lang"]).to_s
    return "en" if v.empty? || !LANG_OPTIONS.key?(v)
    v
  end
  

  def encode_cursor(hw_lower, id)
    Base64.urlsafe_encode64("#{hw_lower}|#{id}")
  end
  def decode_cursor(cur)
    s = Base64.urlsafe_decode64(cur) rescue nil
    return nil unless s && s.include?("|")
    hw, id = s.split("|", 2)
    [hw, oid(id)]
  end

  def smtp_send(to:, subject:, body:)
    host = ENV.fetch("SMTP_HOST")
    port = Integer(ENV.fetch("SMTP_PORT", "587"))
    user = ENV.fetch("SMTP_USER")
    pass = ENV.fetch("SMTP_PASS")
    from = ENV.fetch("SMTP_FROM")
    msg = <<~EOM
    From: #{from}
    To: #{to}
    Subject: #{subject}
    MIME-Version: 1.0
    Content-Type: text/plain; charset=UTF-8

    #{body}
    EOM
    Net::SMTP.start(host, port, host, user, pass, :login) do |smtp|
      smtp.send_message(msg, from, to)
    end
  end

  def rand_token(n=32) = SecureRandom.urlsafe_base64(n)

  def send_confirm_email!(user)
    base = ENV.fetch("APP_BASE_URL")
    url  = "#{base}/confirm?token=#{user["confirmation_token"]}"
    smtp_send(to: user["email"], subject: "請確認你的帳號", body: "請點選以下連結啟用帳號：\n#{url}\n\n若非本人請忽略。")
  end

  def send_temp_password!(user, tmp_pwd)
    smtp_send(to: user["email"], subject: "你的臨時密碼", body: "以下是你的臨時密碼： #{tmp_pwd}\n登入後請盡快修改密碼。")
  end

  before { cache_control :no_store }
end

require_relative "./routes/auth"
require_relative "./routes/admin"
require_relative "./routes/home"
require_relative "./routes/api"
require_relative "./routes/quiz"
require_relative "./routes/tts"
require_relative "./routes/health"
