class Wordgym < Sinatra::Base
  get "/healthz" do
    "ok"
  end
end