class Wordgym < Sinatra::Base
  namespace "/admin" do
    before { require_admin! }

    get "/users" do
      @users = DB.users.find
                 .projection(email: 1, is_admin: 1, active: 1, created_at: 1, deny_password_change: 1)
                 .sort(created_at: -1)
                 .to_a
      erb %(
        <h2>Users</h2>
        <table>
          <tr><th>Email</th><th>Admin</th><th>Active</th><th>Pwd change</th><th>Created</th><th></th></tr>
          <% @users.each do |u| %>
            <tr>
              <td><%= u["email"] %></td>
              <td><%= u["is_admin"] ? '✓' : '—' %></td>
              <td><%= u["active"]  ? '✓' : '—' %></td>
              <td>
                <% if u["deny_password_change"] %>
                  <span title="此帳號被禁止自行改密碼">禁用</span>
                <% else %>
                  允許
                <% end %>
              </td>
              <td><%= u["created_at"] %></td>
              <td>
                <form method="post" action="/admin/users/<%= u['_id'] %>/toggle_pwd_change" style="display:inline">
                  <button type="submit"><%= u["deny_password_change"] ? '允許改密碼' : '禁用改密碼' %></button>
                </form>
              </td>
            </tr>
          <% end %>
        </table>
        <hr/>
        <form method="post" action="/admin/users">
          <h3>新增使用者</h3>
          <input name="email" placeholder="email">
          <input name="password" placeholder="password">
          <label><input type="checkbox" name="is_admin"> admin</label>
          <label><input type="checkbox" name="active" checked> active</label>
          <label><input type="checkbox" name="deny_password_change"> 禁用改密碼</label>
          <button type="submit">Create</button>
          <br><hr>
          <a href="/admin/auth">Auth Settings</a> · <a href="/admin/invites">Invites</a>
        </form>
      ), layout: :layout
    end

    post "/users" do
      doc = {
        email: params[:email].to_s.strip.downcase,
        password_digest: hash_password(params[:password].to_s),
        is_admin: params[:is_admin] == "on",
        active: params[:active] == "on",
        deny_password_change: params[:deny_password_change] == "on",
        created_at: Time.now.utc,
        updated_at: Time.now.utc
      }
      DB.users.insert_one(doc)
      redirect "/admin/users"
    end

    post "/users/:id/toggle_pwd_change" do
      uid = begin
        oid(params[:id])
      rescue
        halt 400
      end

      u = DB.users.find(_id: uid).projection(deny_password_change: 1).first or halt 404
      new_val = !u["deny_password_change"]
      DB.users.update_one({ _id: uid }, { "$set" => { deny_password_change: new_val, updated_at: Time.now.utc } })
      redirect "/admin/users"
    end

    # Auth settings
    get "/auth" do
      @auth = auth_settings
      erb %(
        <h2>Auth 設定</h2>
        <form method="post" action="/admin/auth">
          <label><input type="checkbox" name="enable_login"     <%= @auth[:enable_login] ? 'checked' : '' %>> 開啟登入</label><br/>
          <label><input type="checkbox" name="enable_register"  <%= @auth[:enable_register] ? 'checked' : '' %>> 開啟註冊</label><br/>
          <label><input type="checkbox" name="require_invite"   <%= @auth[:require_invite] ? 'checked' : '' %>> 註冊需要邀請碼</label><br/>
          <label><input type="checkbox" name="require_captcha"  <%= @auth[:require_captcha] ? 'checked' : '' %>> 顯示驗證碼</label><br/>
          <label><input type="checkbox" name="confirm_by_email" <%= @auth[:confirm_by_email] ? 'checked' : '' %>> 註冊需要 Email 確認</label><br/>
          <button type="submit">儲存</button>
        </form>
        <br><hr>
        <a href="/admin/users">User Management</a> · <a href="/admin/invites">Invites</a>
      ), layout: :layout
    end

    post "/auth" do
      doc = {
        key: "auth",
        enable_login:     params[:enable_login]     == "on",
        enable_register:  params[:enable_register]  == "on",
        require_invite:   params[:require_invite]   == "on",
        require_captcha:  params[:require_captcha]  == "on",
        confirm_by_email: params[:confirm_by_email] == "on",
        updated_at: Time.now.utc
      }
      DB.settings.update_one({ key: "auth" }, { "$set" => doc }, upsert: true)
      redirect "/admin/auth"
    end

    
    # Invites
    get "/invites" do
      @list = DB.invites.find.sort(created_at: -1).to_a
      erb %(
        <h2>邀請碼</h2>
        <form method="post" action="/admin/invites">
          <input name="code" placeholder="8位碼(可空：自動生成)">
          <input name="max_uses" type="number" min="1" max="<%= ENV.fetch('INVITE_MAX_PER_CODE','100') %>" value="<%= ENV.fetch('INVITE_MAX_PER_CODE','100') %>">
          <label><input type="checkbox" name="active" checked> 啟用</label>
          <button type="submit">新增</button>
        </form>
        <hr/>
        <table>
          <tr><th>code</th><th>used/max</th><th>active</th><th>created</th><th></th></tr>
          <% @list.each do |i| %>
            <tr>
              <td><%= i['code'] %></td>
              <td><%= (i['used_count']||0) %> / <%= (i['max_uses']||ENV.fetch('INVITE_MAX_PER_CODE','100').to_i) %></td>
              <td><%= i['active'] ? '✓' : '—' %></td>
              <td><%= i['created_at'] %></td>
              <td>
                <form method="post" action="/admin/invites/<%= i['_id'] %>/delete" style="display:inline" onsubmit="return confirm('刪除？')">
                  <button type="submit">刪除</button>
                </form>
              </td>
            </tr>
          <% end %>
        </table>
      ), layout: :layout
    end

    post "/invites" do
      code = params[:code].to_s.strip
      code = SecureRandom.alphanumeric(8).to_s.upcase if code.empty?
      max  = [[Integer(params[:max_uses] || ENV.fetch("INVITE_MAX_PER_CODE", "100")), 1].max,
              Integer(ENV.fetch("INVITE_MAX_PER_CODE","100"))].min
      DB.invites.insert_one({
        code: code,
        max_uses: max,
        used_count: 0,
        active: (params[:active] == "on"),
        created_at: Time.now.utc,
        updated_at: Time.now.utc
      })
      redirect "/admin/invites"
    end

    post "/invites/:id/delete" do
      DB.invites.delete_one(_id: oid(params[:id]))
      redirect "/admin/invites"
    end
  end
end
