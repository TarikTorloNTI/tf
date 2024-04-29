require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'sinatra/flash'

enable :sessions
require_relative 'model/model.rb'

# Skapar och returnerar en anslutning till databasen.
# @return [SQLite3::Database] en ansluten och konfigurerad databasinstans.
helpers do
  def db_connection
    db = SQLite3::Database.new('db/user.db')
    db.results_as_hash = true
    db
  end

  # Kontrollerar om en användare är inloggad genom att kontrollera sessionen.
  # @return [Boolean] True om användaren är inloggad, annars false.
  def logged_in?
    !session[:user_id].nil?
  end 


  # Kontrollerar om den inloggade användaren är administratör.
  # @return [Boolean] True om användaren är administratör, annars false.
  def is_admin?
    session[:role_value] == 2
  end

  # Validerar att den inloggade användaren äger den efterfrågade resursen.
  # @param resource_id [Integer] ID för den resurs som ska valideras.
  # @return [Boolean] True om användaren äger resursen, annars false.
  def validate_user(resource_id)
    user_id = db_connection.execute("SELECT user_id FROM \"user-gymlog\" WHERE gymlog_id = ?", resource_id).first['user_id']
    session[:user_id] == user_id
  end
end

before do
  @db = db_connection
end

# Säkerställer att användare är inloggad innan åtkomst till vissa sidor ges.
before ['/gymlog/*', '/exercise/*', '/users/*'] do
  redirect('/showlogin') unless logged_in?
end

# Visar startsidan för applikationen.
# @return [String] Renderar startsidan med layout.
get('/') do
  slim :start, layout: :login_layout
end


# Visar inloggningsformuläret.
# @return [String] Renderar inloggningsformuläret.
get('/showlogin') do
  slim :login, layout: :login_layout
end


# Hanterar inloggning av en användare.
# @param username [String] Användarnamnet som används för att logga in.
# @param password [String] Lösenordet som används för att verifiera användaren.
# @return [String] Omdirigerar till startsidan om autentisering lyckas, annars returneras felmeddelande.
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



# Loggar ut användaren och rensar sessionen.
# @return [String] Omdirigerar till startsidan efter utloggning.
post('/logout') do
  session.clear
  redirect '/'
end


# Tillåter användare att logga in som gäster.
# @return [String] Omdirigerar till den inloggade startsidan.
get('/guest_login') do
  session[:role_value] = 0
  redirect '/start_login'
end

# Visar sidan som användaren ser efter att ha loggat in.
# @return [String] Renderar den inloggade användarens sida.
get('/start_login') do
  slim :loggedin
end


# Skapar en ny användare i systemet.
# @param username [String] Användarnamnet för den nya användaren.
# @param password [String] Lösenordet för den nya användaren.
# @param password_confirm [String] Bekräftelse av lösenordet.
# @return [String] Omdirigerar till startsidan efter lyckad registrering, annars visas felmeddelande.
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



# Visar alla gymloggar för en inloggad användare.
# @return [String] Renderar sidan med användarens gymloggar om inloggad, annars visas gästsidan.
get('/gymlog') do
  if [1, 2].include?(session[:role_value])
    # Notera användningen av dubbla citattecken runt tabellnamn och kolumnnamn med bindestreck
    @result = @db.execute("SELECT gymlog.* FROM gymlog INNER JOIN \"user-gymlog\" ON gymlog.id = \"user-gymlog\".gymlog_id WHERE \"user-gymlog\".user_id = ?", session[:user_id])
    slim :"gymlog/index"
  else
    slim :"gymlog/guest"
  end
end


# Hanterar radering av en specifik gymlogg.
# @param id [Integer] ID för gymloggen som ska raderas.
# @return [String] Omdirigerar användaren tillbaka till gymloggsidan efter att loggen har raderats.
post('/gymlog/:id/delete') do
  halt 403, "Access Denied" unless validate_user(params[:id].to_i)
  @db.execute("DELETE FROM gymlog WHERE id = ?", params[:id])
  redirect '/gymlog'
end

# Visar formuläret för att skapa en ny gymlogg.
# @return [String] Renderar formuläret för ny gymlogg.
get('/gymlog/new') do
  slim :"gymlog/new"
end


# Skapar en ny gymlogg och lagrar den i databasen.
# @param dag [String] Datumet för gymloggen.
# @param exercise [String] Beskrivning av övningen.
# @return [String] Omdirigerar användaren tillbaka till gymloggsidan efter att loggen har sparats.
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

# Visar sidan för att redigera en befintlig gymlogg.
# @param id [Integer] ID för gymloggen som ska redigeras.
# @return [String] Renderar redigeringsformuläret för gymloggen.
get('/gymlog/:id/edit') do
  halt 403, "Access Denied" unless validate_user(params[:id].to_i)
  @result = @db.execute("SELECT * FROM gymlog WHERE id = ?", params[:id]).first
  slim :"gymlog/edit"
end


# Uppdaterar en befintlig gymlogg i databasen.
# @param id [Integer] ID för gymloggen som ska uppdateras.
# @param dag [String] Uppdaterat datum för gymloggen.
# @param exercise [String] Uppdaterad beskrivning av övningen.
# @return [String] Omdirigerar användaren tillbaka till gymloggsidan efter uppdatering.
post('/gymlog/:id/update') do
  halt 403, "Access Denied" unless validate_user(params[:id].to_i)
  dag = params[:dag]
  exercise = params[:exercise]
  @db.execute("UPDATE gymlog SET dag = ?, exercise = ? WHERE id = ?", dag, exercise, params[:id])
  redirect '/gymlog'
end


# Visar alla övningstyper tillgängliga i systemet.
# @return [String] Renderar sidan med en lista över övningstyper.
get('/type') do
  @result = @db.execute("SELECT * FROM type")
  slim :"type/index2"
end

# Visar övningar för en specifik övningstyp.
# @param type_of [String] Typ av övningar att visa baserat på deras ID.
# @return [String] Renderar sidan med övningar för en specifik muskelgrupp.
get('/index2/:type_of') do
  type_of = params[:type_of]
  @result = @db.execute("SELECT * FROM exercise WHERE \"type-id\" = ?", type_of)
  admin_access = is_admin?
  puts "Admin access: #{admin_access}"  # Logga för att se om det är true eller false
  slim :"exercise/index3", locals: { admin_access: admin_access }
end


# Raderar en specifik övning.
# @param id [Integer] ID för övningen som ska raderas.
# @return [String] Omdirigerar till övningstyperna efter att övningen har raderats.
post('/exercise/:id/delete') do
  halt 403, "Access Denied" unless is_admin?
  @db.execute("DELETE FROM exercise WHERE id = ?", params[:id])
  redirect '/type'
end


# Visar formuläret för att lägga till en ny övning.
# @return [String] Renderar formuläret för att lägga till en ny övning.
get('/exercise/new') do
  @result = @db.execute("SELECT * FROM type")
  slim :"exercise/new2"
end


# Skapar en ny övning och lägger till den i databasen.
# @param exercise [String] Namnet på övningen som ska läggas till.
# @param type_id [Integer] Typ-ID för övningen.
# @return [String] Omdirigerar till övningstyperna efter att övningen har skapats.
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


# Visar sidan för att redigera en befintlig övning.
# @param id [Integer] ID för övningen som ska redigeras.
# @return [String] Renderar redigeringsformuläret för övningen.
get('/exercise/:id/edit') do
  halt 403, "Access Denied" unless is_admin?
  @result = @db.execute("SELECT * FROM exercise WHERE id = ?", params[:id]).first
  slim :"exercise/edit2"
end


# Uppdaterar en befintlig övning i databasen.
# @param id [Integer] ID för övningen som ska uppdateras.
# @param exercise [String] Det uppdaterade namnet på övningen.
# @return [String] Omdirigerar till övningstyperna efter att övningen har uppdaterats.
post('/exercise/:id/update') do
  halt 403, "Access Denied" unless is_admin?
  exercise = params[:exercise]
  @db.execute("UPDATE exercise SET exercise = ? WHERE id = ?", exercise, params[:id])
  redirect '/type'
end