class Wordgym < Sinatra::Base
  before "/" do
    require_login!
  end

  get "/" do
    filter = { user_id: current_user["_id"] }
    if %w[true false].include?(params[:remembered].to_s)
      filter[:remembered] = (params[:remembered] == "true")
    end
    raw_cats = params[:cat] || params[:cats] || params[:category] || params[:categories]
    cat_ids = arr_oids(raw_cats)
    filter[:category_ids] = { "$in" => cat_ids } if cat_ids.any?

    @words = DB.words
               .find(filter)
               .projection(headword: 1, definition_zh: 1, definition: 1, remembered: 1)
               .sort(headword_lower: 1)
               .limit(200).to_a

    @pos_options = POS_OPTIONS
    @categories = DB.categories
                    .find(user_id: current_user["_id"])
                    .projection(name: 1)
                    .sort(name: 1).to_a
    erb :home
  end

  get "/words/:id" do
    require_login!
    @word = DB.words.find(_id: oid(params[:id]), user_id: current_user["_id"]).first or halt 404
    erb :word_show
  end

  get "/words/:id/partial" do
    require_login!
    id = begin
      oid(params[:id])
    rescue
      halt 400
    end

    @word = DB.words.find(_id: id, user_id: current_user["_id"]).first or halt 404

    ids = Array(@word["category_ids"]).compact
    @word_categories = []
    if ids.any?
      @word_categories = DB.categories
                           .find({ _id: { "$in" => ids }, user_id: current_user["_id"] })
                           .projection(name: 1).to_a
    end

    @all_categories = DB.categories
                        .find(user_id: current_user["_id"])
                        .projection(name: 1)
                        .sort(name: 1).to_a

    erb :_word_modal, layout: false
  end

  get "/words/:id/edit" do
    require_login!
    @word = DB.words.find(_id: oid(params[:id]), user_id: current_user["_id"]).first or halt 404
    @pos_options = POS_OPTIONS
    erb :word_edit
  end
end
