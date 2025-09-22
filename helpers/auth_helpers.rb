require "bcrypt"
require "securerandom"
require "json"
require "bson"

module AuthHelpers
  def current_user
    return @current_user if defined?(@current_user)
    uid = session[:uid]
    @current_user = uid ? DB.users.find(_id: BSON::ObjectId(uid)).first : nil
  end

  def logged_in?
    !!current_user
  end

  def require_login!
    redirect "/login" unless logged_in?
  end

  def require_admin!
    halt 403, "Forbidden" unless logged_in? && current_user["is_admin"]
  end

  def hash_password(plain)
    BCrypt::Password.create(plain)
  end

  def verify_password?(digest, plain)
    BCrypt::Password.new(digest) == plain
  end

  def oid(str)
    BSON::ObjectId(str)
  end
end
