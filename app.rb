require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'sinatra/flash'

enable :sessions
require_relative 'model/model'

helpers do
  def db_connection
    db = SQLite3::Database.new('db/user.db')
    db.results_as_hash = true
    db
  end

  def logged_in?
    !session[:user_id].nil?
  end

  def is_admin?
    session[:role_value] == 2
  end

  def validate_user(resource_id)
    user_id = db_connection.execute("SELECT user_id FROM \"user-gymlog\" WHERE gymlog_id = ?", resource_id).first['user_id']
    session[:user_id] == user_id
  end
end

before do
  @db = db_connection
end

before ['/gymlog/*', '/exercise/*', '/users/*'] do
  redirect('/showlogin') unless logged_in?
end

get('/') do
  slim :start, layout: :login_layout
end

get('/showlogin') do
  slim :login, layout: :login_layout
end

post('/login') do
  username = params[:username].strip
  password = params[:password]
  
  begin
    user = @db.execute("SELECT * FROM user WHERE username = ?", username).first
    puts "Login attempt for user: #{user}"
    
    if user && BCrypt::Password.new(user["password"]) == password
      session[:user_id] = user["id"]
      session[:role_value] = user["role"]
      redirect '/start_login'
    else
      puts "Login failed for username: #{username} with provided password."
      "Incorrect username or password!"
    end
  rescue SQLite3::Exception => e
    puts "Login error: #{e.message}"
    "Login error: #{e.message}"
  end
end




post('/logout') do
  session.clear
  redirect '/'
end

get('/guest_login') do
  session[:role_value] = 0
  redirect '/start_login'
end

get('/start_login') do
  slim :loggedin
end

post('/users/new') do
  username = params[:username].strip
  password = params[:password]
  password_confirm = params[:password_confirm]
  
  puts "Username: #{username}, Password: #{password}, Confirm: #{password_confirm}"

  if password == password_confirm
    password_digest = BCrypt::Password.create(password)
    puts "Password Digest: #{password_digest}"
    role = (username.downcase == "admin" ? 2 : 1)

    begin
      @db.execute("INSERT INTO user (username, password, role) VALUES (?, ?, ?)", username, password_digest, role)
      puts "User created: #{username} with role #{role}"
      redirect '/'
    rescue SQLite3::Exception => e
      puts "Database error during user creation: #{e.message}"
      "Database error: #{e.message}"
    end
  else
    "Passwords do not match!"
  end
end





get('/gymlog') do
  if [1, 2].include?(session[:role_value])
    # Notera användningen av dubbla citattecken runt tabellnamn och kolumnnamn med bindestreck
    @result = @db.execute("SELECT gymlog.* FROM gymlog INNER JOIN \"user-gymlog\" ON gymlog.id = \"user-gymlog\".gymlog_id WHERE \"user-gymlog\".user_id = ?", session[:user_id])
    slim :"gymlog/index"
  else
    slim :"gymlog/guest"
  end
end


post('/gymlog/:id/delete') do
  halt 403, "Access Denied" unless validate_user(params[:id].to_i)
  @db.execute("DELETE FROM gymlog WHERE id = ?", params[:id])
  redirect '/gymlog'
end

get('/gymlog/new') do
  slim :"gymlog/new"
end

post('/gymlog/new') do
  dag = params[:dag]
  exercise = params[:exercise]
  user_id = session[:user_id]  # Se till att detta värde är korrekt och inte nil

  # Använd dubbla citattecken runt tabell- och kolumnnamn med bindestreck
  @db.execute("INSERT INTO gymlog (dag, exercise, \"user-id\") VALUES (?, ?, ?)", dag, exercise, user_id)
  gymlog_id = @db.last_insert_row_id
  @db.execute("INSERT INTO \"user-gymlog\" (user_id, gymlog_id) VALUES (?, ?)", user_id, gymlog_id)
  redirect '/gymlog'
end


get('/gymlog/:id/edit') do
  halt 403, "Access Denied" unless validate_user(params[:id].to_i)
  @result = @db.execute("SELECT * FROM gymlog WHERE id = ?", params[:id]).first
  slim :"gymlog/edit"
end

post('/gymlog/:id/update') do
  halt 403, "Access Denied" unless validate_user(params[:id].to_i)
  dag = params[:dag]
  exercise = params[:exercise]
  @db.execute("UPDATE gymlog SET dag = ?, exercise = ? WHERE id = ?", dag, exercise, params[:id])
  redirect '/gymlog'
end

get('/type') do
  @result = @db.execute("SELECT * FROM type")
  slim :"type/index2"
end

get '/index2/:type_of' do
  type_of = params[:type_of]
  @result = @db.execute("SELECT * FROM exercise WHERE \"type-id\" = ?", type_of)
  admin_access = is_admin?
  puts "Admin access: #{admin_access}"  # Logga för att se om det är true eller false
  slim :"exercise/index3", locals: { admin_access: admin_access }
end


post('/exercise/:id/delete') do
  halt 403, "Access Denied" unless is_admin?
  @db.execute("DELETE FROM exercise WHERE id = ?", params[:id])
  redirect '/type'
end

get('/exercise/new') do
  @result = @db.execute("SELECT * FROM type")
  slim :"exercise/new2"
end

post('/exercise/new') do
  exercise = params[:exercise]
  type_id = params['type-id'].to_i  # Säkerställ att detta är rätt parameter som tas emot

  puts "Received type-id: #{type_id}"  # Debugging för att visa mottaget type-id

  if type_id.between?(1, 5)
    @db.execute("INSERT INTO exercise (exercise, \"type-id\") VALUES (?, ?)", exercise, type_id)
    redirect '/type'
  else
    "Invalid muscle group selected"  # Informera användaren om att ett ogiltigt värde har valts
  end
end

get('/exercise/:id/edit') do
  halt 403, "Access Denied" unless is_admin?
  @result = @db.execute("SELECT * FROM exercise WHERE id = ?", params[:id]).first
  slim :"exercise/edit2"
end

post('/exercise/:id/update') do
  halt 403, "Access Denied" unless is_admin?
  exercise = params[:exercise]
  @db.execute("UPDATE exercise SET exercise = ? WHERE id = ?", exercise, params[:id])
  redirect '/type'
end