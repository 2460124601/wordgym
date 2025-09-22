class Wordgym < Sinatra::Base
  namespace "/api" do
    before do
      require_login!
      content_type :json
    end

    # Create a word
    post "/words" do
      payload = JSON.parse(request.body.read) rescue {}
      headword = payload["headword"].to_s.strip
      halt 422, json(error: "headword 不可為空") if headword.empty?

      pos           = Array(payload["pos"]).map(&:to_s).select { |p| POS_OPTIONS.include?(p) }
      definition_zh = payload["definition_zh"].to_s
      definition_en = payload["definition_en"].to_s
      definition_zh = payload["definition"].to_s if definition_zh.empty? && payload["definition"]

      example       = payload["example"].to_s
      example2      = payload["example2"].to_s
      cambridge     = payload["cambridge_url"].to_s
      cat_ids = arr_oids(payload["category_ids"])
      if cat_ids.any?
        valid_ids = DB.categories.find({ _id: { "$in" => cat_ids }, user_id: current_user["_id"] })
                      .projection(_id: 1).to_a.map { |c| c["_id"] }
        cat_ids = valid_ids
      end

      now = Time.now.utc
      doc = {
        user_id:         current_user["_id"],
        headword:        headword,
        headword_lower:  headword.downcase,
        first_letter:    latin_initial(headword),
        pos:             pos,
        definition_zh:   definition_zh,
        definition_en:   definition_en,
        example:         example,
        example2:        example2,
        cambridge_url:   cambridge,
        category_ids:    cat_ids,
        remembered:      false,
        review_count:    0,
        created_at:      now,
        updated_at:      now
      }

      reading_ja = payload["reading_ja"].to_s
      if reading_ja.empty? && user_word_lang == "ja" && headword.match?(/[\p{Hiragana}\p{Katakana}]/)
        reading_ja = headword
      end
      unless reading_ja.empty?
        norm = ja_normalize_kana(reading_ja)
        doc[:reading_ja]  = norm
        doc[:reading_row] = ja_row_key(norm)
      end

      begin
        res = DB.words.insert_one(doc)
        json(ok: true, id: res.inserted_id.to_s)
      rescue Mongo::Error::OperationFailure
        halt 409, json(error: "已存在相同單字")
      end
    end

    # Update a word
    patch "/words/:id" do
      data = JSON.parse(request.body.read) rescue {}
      doc = DB.words.find(_id: oid(params[:id]), user_id: current_user["_id"]).first or halt 404

      updates = {}
      if data.key?("headword")
        hw = data["headword"].to_s.strip
        halt 422, json(error: "headword 不可為空") if hw.empty?
        updates[:headword]        = hw
        updates[:headword_lower]  = hw.downcase
        updates[:first_letter]    = latin_initial(hw)
      end

      if data.key?("pos")
        pos = Array(data["pos"]).map(&:to_s).select { |p| POS_OPTIONS.include?(p) }
        updates[:pos] = pos
      end

      %w[definition_zh definition_en example example2 cambridge_url].each do |k|
        next unless data.key?(k)
        updates[k.to_sym] = data[k].to_s
        updates[:definition] = updates[:definition_zh] if k == "definition_zh"
      end

      updates[:remembered] = !!data["remembered"] if data.key?("remembered")

      if data.key?("category_ids")
        cat_ids = arr_oids(data["category_ids"])
        if cat_ids.any?
          valid_ids = DB.categories.find({ _id: { "$in" => cat_ids }, user_id: current_user["_id"] })
                        .projection(_id: 1).to_a.map { |c| c["_id"] }
          cat_ids = valid_ids
        end
        updates[:category_ids] = cat_ids
      end

      if data.key?("reading_ja")
        rj = data["reading_ja"].to_s
        updates[:reading_ja]  = rj
        updates[:reading_row] = (rj.empty? ? "#" : ja_row_key(rj))
      end

      halt 422, json(error: "沒有任何可更新欄位") if updates.empty?
      updates[:updated_at] = Time.now.utc

      begin
        DB.words.update_one({ _id: doc["_id"] }, { "$set" => updates })
      rescue Mongo::Error::OperationFailure
        halt 409, json(error: "同用戶已存在相同單字")
      end

      json(ok: true)
    end

    # List categories
    get "/categories" do
      list = DB.categories.find(user_id: current_user["_id"]).projection(name: 1).sort(name: 1).to_a
      json(items: list.map { |c| { _id: c["_id"].to_s, name: c["name"] } })
    end


    # Create category
    post "/categories" do
      payload = JSON.parse(request.body.read) rescue {}
      name = payload["name"].to_s.strip
      halt 422, json(error: "name 不可為空") if name.empty?
      now = Time.now.utc
      begin
        res = DB.categories.insert_one({ user_id: current_user["_id"], name: name, created_at: now, updated_at: now })
      rescue Mongo::Error::OperationFailure
        halt 409, json(error: "類別已存在")
      end
      json(id: res.inserted_id.to_s, name: name)
    end

    # Delete category
    delete "/categories/:id" do
      begin
        cat_id = oid(params[:id])
      rescue
        halt 400, json(error: "bad id")
      end
      r = DB.categories.delete_one(_id: cat_id, user_id: current_user["_id"])
      halt 404, json(error: "not found") if r.deleted_count != 1
      DB.words.update_many({ user_id: current_user["_id"], category_ids: cat_id }, { "$pull" => { category_ids: cat_id } })
      json(ok: true)
    end

    # Paginated list of words
    get "/words/list" do
      limit = params[:limit].to_i
      limit = 50 if limit <= 0
      limit = 200 if limit > 200

      filter = { user_id: current_user["_id"] }

      raw_cats = params[:cat] || params[:cats] || params[:category] || params[:categories]
      cat_ids = arr_oids(raw_cats)
      filter[:category_ids] = { "$in" => cat_ids } if cat_ids.any?

      if %w[true false].include?(params[:remembered].to_s)
        filter[:remembered] = params[:remembered] == "true"
      end

      initial = params[:initial].to_s.strip
      unless initial.empty?
        if user_word_lang == "ja"
          if initial == "#"
            filter["$or"] = [
              { reading_row: { "$in": [nil, "", "#"] } },
              { reading_ja:  { "$in": [nil, ""] } }
            ]
          else
            filter[:reading_row] = initial
          end
        else
          filter[:first_letter] = (initial == "#") ? "#" : initial[0].upcase
        end
      end

      starts = params[:starts].to_s.strip
      unless starts.empty?
        if user_word_lang == "ja"
          ks = ja_normalize_kana(starts)
          filter[:reading_ja] = { "$regex" => "^#{Regexp.escape(ks)}" }
        else
          filter[:headword_lower] = { "$regex" => "^#{Regexp.escape(starts.downcase)}" }
        end
      end

      pos = Array(params[:pos]).map(&:to_s) & POS_OPTIONS
      filter[:pos] = { "$in" => pos } unless pos.empty?

      random = params[:random].to_s == "true"
      total = DB.words.count_documents(filter)

      if random
        size = [limit, 50].min
        docs = DB.words.aggregate([
                                    { "$match" => filter },
                                    { "$sample" => { size: size } },
                                    { "$project" => { headword: 1, definition_zh: 1, definition: 1, remembered: 1, headword_lower: 1 } }
                                  ]).to_a
        return json({
                      items: docs.map { |w| { id: w["_id"].to_s, headword: w["headword"], zh: (w["definition_zh"] || w["definition"]).to_s, remembered: !!w["remembered"] } },
                      next_cursor: nil,
                      total: total
                    })
      end

      sort = { headword_lower: 1, _id: 1 }
      q = filter.dup
      if (after = params[:after].to_s).size > 0
        hw, last_id = decode_cursor(after) rescue [nil, nil]
        if hw && last_id
          cursor_cond = { "$or" => [ { headword_lower: { "$gt" => hw } }, { headword_lower: hw, _id: { "$gt" => last_id } } ] }
          q = { "$and" => [filter, cursor_cond] }
        end
      end

      items = DB.words
                .find(q)
                .projection(headword: 1, definition_zh: 1, definition: 1, remembered: 1, headword_lower: 1)
                .sort(sort)
                .limit(limit)
                .to_a

      next_cursor = nil
      if items.size == limit
        last = items.last
        next_cursor = encode_cursor(last["headword_lower"], last["_id"].to_s)
      end

      json({
             items: items.map { |w| { id: w["_id"].to_s, headword: w["headword"], zh: (w["definition_zh"] || w["definition"]).to_s, remembered: !!w["remembered"] } },
             next_cursor: next_cursor,
             total: total
           })
    end

    # Mark remembered (explicit)
    patch "/words/:id/remembered" do
      id = params[:id]
      data = JSON.parse(request.body.read) rescue {}
      remembered = !!data["remembered"]
      q = { _id: oid(id), user_id: current_user["_id"] }
      r = DB.words.update_one(q, { "$set" => { remembered: remembered, updated_at: Time.now.utc } })
      halt 404 unless r.matched_count == 1
      json(ok: true, remembered: remembered)
    end


    # Get a single word (+ options for edit modal)
    get "/words/:id" do
      begin
        wid = oid(params[:id])
      rescue
        halt 400, json(error: "invalid id")
      end
      w = DB.words.find(_id: wid, user_id: current_user["_id"]).first or halt 404, json(error: "not found")
      cats = DB.categories
               .find(user_id: current_user["_id"]) \
               .projection(_id: 1, name: 1)
               .sort(name: 1)
               .map { |c| { "_id" => c["_id"].to_s, "name" => c["name"] } }
      json({
             id: w["_id"].to_s,
             headword: w["headword"],
             pos: Array(w["pos"]),
             definition_zh: w["definition_zh"],
             definition_en: w["definition_en"],
             example: w["example"],
             example2: w["example2"],
             cambridge_url: w["cambridge_url"],
             remembered: !!w["remembered"],
             category_ids: Array(w["category_ids"]).map(&:to_s),
             all_categories: cats,
             pos_options: POS_OPTIONS
           })
    end

    # Delete a word
    delete "/words/:id" do
      begin
        id = oid(params[:id])
      rescue
        halt 400, json(error: "invalid id")
      end
      result = DB.words.delete_one(_id: id, user_id: current_user["_id"])
      halt 404, json(error: "not found") unless result.deleted_count == 1
      json(ok: true)
    end

    # Toggle remembered
    patch "/words/:id/toggle_remembered" do
      begin
        id = oid(params[:id])
      rescue
        halt 400, json(error: "invalid id")
      end
      doc = DB.words.find(_id: id, user_id: current_user["_id"]).first or halt 404, json(error: "not found")
      new_val = !doc["remembered"]
      DB.words.update_one({ _id: doc["_id"] }, { "$set" => { remembered: new_val, updated_at: Time.now.utc } })
      json(ok: true, remembered: new_val)
    end

    # Quiz question (MCQ)
    get "/quiz/question" do
      only_unremembered = params.fetch("only_unremembered", "true") == "true"
      pool_match = { user_id: current_user["_id"] }
      pool_match[:remembered] = false if only_unremembered

      word = DB.words.aggregate([
                                  { "$match" => pool_match.merge({ "$or" => [
                                    { "definition_zh" => { "$exists" => true, "$ne" => "" } },
                                    { "definition"    => { "$exists" => true, "$ne" => "" } }
                                  ] }) },
                                  { "$sample" => { size: 1 } }
                                ]).first
      halt 404, json(error: "題庫不足") unless word

      correct_text = (word["definition_zh"] || "").to_s.strip
      correct_text = (word["definition"]    || "").to_s.strip if correct_text.empty?
      halt 404, json(error: "該單字缺少中文解釋") if correct_text.empty?

      others = DB.words.aggregate([
                                    { "$match" => {
                                      user_id: current_user["_id"],
                                      _id: { "$ne" => word["_id"] },
                                      "$or" => [
                                        { "definition_zh" => { "$exists" => true, "$ne" => "" } },
                                        { "definition"    => { "$exists" => true, "$ne" => "" } }
                                      ]
                                    } },
                                    { "$sample" => { size: 50 } }
                                  ]).to_a
      distractors_pool = others.map do |w|
        x = (w["definition_zh"] || "").to_s.strip
        x = (w["definition"]    || "").to_s.strip if x.empty?
        x
      end.select { |s| !s.empty? && s != correct_text }.uniq

      distractors = distractors_pool.sample(3) || []
      distractors += ["（選項不足，請多新增中文解釋）"] * (3 - distractors.size) if distractors.size < 3

      options = (distractors + [correct_text]).shuffle
      answer_index = options.index(correct_text)

      json({ id: word["_id"].to_s, headword: word["headword"], options: options, answer_index: answer_index })
    end
  end
end
