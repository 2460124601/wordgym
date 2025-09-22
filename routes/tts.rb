class Wordgym < Sinatra::Base
  get "/tts/google" do
    require_login!
    text = params[:text].to_s.strip
    halt 422, "no text" if text.empty?
    lang = resolve_tts_lang(params[:tl])

    uri = URI("https://translate.google.com/translate_tts")
    q = { ie: "UTF-8", total: 1, idx: 0, textlen: text.length, client: "tw-ob", q: text, tl: lang }
    uri.query = URI.encode_www_form(q)

    http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true
    req = Net::HTTP::Get.new(uri.request_uri); req["User-Agent"] = "Mozilla/5.0"
    res = http.request(req); halt 502, "tts error" unless res.is_a?(Net::HTTPSuccess)

    headers "X-TTS-Lang" => lang, "X-TTS-URL" => uri.to_s
    content_type "audio/mpeg"
    res.body
  end
end