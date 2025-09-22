class Wordgym < Sinatra::Base
  get "/quiz" do
    require_login!
    erb :quiz
  end
end