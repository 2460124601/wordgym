# frozen_string_literal: true
class Wordgym < Sinatra::Base
  # Login / Logout
  get "/login" do
    halt 403, "登入已關閉" unless auth_settings[:enable_login]
    redirect "/" if logged_in?
    erb :login
  end

  post "/login" do
    halt 403, "登入已關閉" unless auth_settings[:enable_login]
    if auth_settings[:require_captcha]
      given = params[:captcha].to_s.strip.upcase
      code  = session[:captcha].to_s
      unless !code.empty? && given == code
        @error = "驗證碼錯誤"
        @email = params[:email].to_s
        status 422
        halt erb :login
      end
      session[:captcha] = nil
    end

    email = params[:email].to_s.strip.downcase
    pwd   = params[:password].to_s
    user  = DB.users.find(email: email, active: true).first

    if user && verify_password?(user["password_digest"], pwd)
      session[:uid] = user["_id"].to_s
      redirect "/"
    else
      @error = "信箱或密碼錯誤，或帳號未啟用"
      erb :login
    end
  end

  get "/logout" do
    session.clear
    redirect "/login"
  end

  # Register aka signup
  get "/register" do
    halt 403, "目前關閉註冊" unless auth_settings[:enable_register]
    erb :register
  end

  post "/register" do
    halt 403, "目前關閉註冊" unless auth_settings[:enable_register]

    if auth_settings[:require_invite]
      code = params[:invite_code].to_s.strip
      halt 422, "需要邀請碼" if code.empty?
      inv = DB.invites.find(code: code, active: true).first or halt 422, "邀請碼無效"
      max  = Integer(inv["max_uses"] || ENV.fetch("INVITE_MAX_PER_CODE", "100"))
      used = Integer(inv["used_count"] || 0)
      halt 422, "邀請碼已達上限" if used >= max
    end

    email = params[:email].to_s.strip.downcase
    pwd   = params[:password].to_s
    halt 422, "Email / 密碼不可為空" if email.empty? || pwd.empty?

    now = Time.now.utc
    doc = {
      email: email,
      password_digest: hash_password(pwd),
      is_admin: false,
      active: (auth_settings[:confirm_by_email] ? false : true),
      created_at: now, updated_at: now
    }
    doc[:confirmation_token] = rand_token(24) if auth_settings[:confirm_by_email]

    begin
      DB.users.insert_one(doc)
    rescue Mongo::Error::OperationFailure
      halt 409, "Email 已被使用"
    end

    if auth_settings[:require_invite]
      DB.invites.update_one({ code: code, active: true }, { "$inc" => { used_count: 1 } })
    end

    if auth_settings[:confirm_by_email]
      user = DB.users.find(email: email).first
      send_confirm_email!(user)
      halt 200, "已寄送確認信到 #{email}，請收信啟用帳號"
    else
      redirect "/login"
    end
  end

  # /me
  before "/me*" do
    require_login!
  end

  get "/me" do
    @user = current_user
    @lang_options = LANG_OPTIONS
    erb :me, layout: :layout
  end

  post "/me" do
    email = params[:email].to_s.strip.downcase
    name  = params[:name].to_s.strip
    lang  = params[:word_lang].to_s

    def valid_email?(email)
      !!(email =~ /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    end

    halt 422, "Email 格式不正確" unless valid_email?(email)
    halt 422, "不支援的語系" unless LANG_OPTIONS.key?(lang)

    if email != current_user["email"]
      exists = DB.users.find(email: email).projection(_id: 1).first
      halt 409, "Email 已被使用" if exists
    end

    DB.users.update_one(
      { _id: current_user["_id"] },
      { "$set" => { email: email, name: name, word_lang: lang, updated_at: Time.now.utc } }
    )

    redirect "/me?ok=1"
  end

  post "/me/password" do
    # 防護：如果管理員標記此帳號不可改密碼
    halt 403, "此帳號已停用密碼變更" if current_user["deny_password_change"]

    current = params[:current_password].to_s
    newp    = params[:new_password].to_s
    confirm = params[:new_password_confirmation].to_s

    halt 422, "新密碼不可為空" if newp.empty?
    halt 422, "新密碼與確認不一致" if newp != confirm
    halt 403, "目前密碼錯誤" unless verify_password?(current_user["password_digest"], current)

    DB.users.update_one(
      { _id: current_user["_id"] },
      { "$set" => { password_digest: hash_password(newp), updated_at: Time.now.utc } }
    )

    redirect "/me?pwd=1"
  end

  # Email confirmation & password reset
  get "/confirm" do
    token = params[:token].to_s
    halt 400, "token 不可為空" if token.empty?
    r = DB.users.update_one({ confirmation_token: token, active: false },
                            { "$set" => { active: true, confirmed_at: Time.now.utc },
                              "$unset" => { confirmation_token: "" } })
    if r.modified_count == 1
      "帳號已啟用，請前往登入"
    else
      halt 400, "確認連結無效或已使用"
    end
  end

  get "/forgot" do
    erb :forgot
  end

  post "/forgot" do
    if auth_settings[:require_captcha]
      given = params[:captcha].to_s.strip.upcase
      code  = session[:captcha].to_s
      unless !code.empty? && given == code
        halt 422, "驗證碼錯誤"
      end
      session[:captcha] = nil
    end

    email = params[:email].to_s.strip.downcase
    user  = DB.users.find(email: email, active: true).first or halt 404, "查無此帳號"

    # 防護：禁止改密碼的帳號在忘記密碼流程也要擋掉
    halt 403, "此帳號已停用密碼變更" if user["deny_password_change"]

    tmp   = SecureRandom.alphanumeric(10)
    DB.users.update_one(
      { _id: user["_id"] },
      { "$set" => { password_digest: hash_password(tmp), updated_at: Time.now.utc } }
    )

    send_temp_password!(user, tmp)
    "已寄送臨時密碼至你的信箱"
  end

  # Captcha

  get "/captcha/new" do
    content_type :json
    code = SecureRandom.alphanumeric(5).upcase
    session[:captcha] = code
    headers "Cache-Control" => "no-store"
    json(code: code)
  end
end
