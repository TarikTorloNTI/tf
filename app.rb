require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'sinatra/flash'

enable :sessions


# Visar startsidan
# @return [Slim::Template] Renderar startsidan med layout :login_layout
get('/') do
    slim(:start, layout: :login_layout)
end


# Visar inloggningsformuläret
# @return [Slim::Template] Renderar inloggningsformuläret med layout :login_layout
get('/showlogin') do
  slim(:login, layout: :login_layout)
end


# Loggar in en användare
# @param [String] username Användarnamnet som skickas från inloggningsformuläret
# @param [String] password Lösenordet som skickas från inloggningsformuläret
# @return [String] Dirigerar användaren till '/start_login' om inloggningen är lyckad, annars visas felmeddelande som antingen är fel lösenord eller inget input
post('/login') do
  username = params[:username]
  password = params[:password]
  db = SQLite3::Database.new('db/user.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM user WHERE username = ?", username).first
  password_digest = result["password"]
  id = result["id"]
  role = result["role"]
  role_name = case role
              when 0
                "Gäst"
              when 1
                "Vanlig användare"
              when 2
                "Administratör"
              else
                "Okänd roll"
              end

  if BCrypt::Password.new(password_digest) == password
    session[:user_id] = id
    session[:role_value] = role.to_i  # Rollen konverteras till en siffra och får därmed ett värde
    puts "Användarens roll är: #{role_name}"
    redirect '/start_login'
  else
    "Felaktigt lösenord! Var vänlig och kontrollera att du skrivit in rätt lösenord."
  end
end


# Rensar användarens session och loggar ut användaren
# @return [Redirect] Omdirigerar användaren tillbaka till startsidan
post('/logout') do
  session.clear
  redirect '/'
end


# Loggar in användaren som gäst när användaren trycker på knappen "Fortsätt som gäst"
# @note Detta sätter ':role_value' i sessionen till 0 för gästanvändare
# @return [Redirect] Omdirigerar användaren till '/start_login'
get('/guest_login') do
  session[:role_value] = 0 # Sätt rollen till 0 för gästanvändaren
  redirect('/start_login')
end


# Startsidan kommer upp efter inloggning och därmed är synlig för användaren
# @return [Slim::Template] Renderar sidan för inloggade användare
get('/start_login') do 
  slim(:loggedin)
end


# Skapar en ny användare
# @param [String] username Det nya användarnamnet
# @param [String] password Det nya lösenordet
# @param [String] password_confirm Lösenordsbekräftelsen
# @return [Redirect] Omdirigerar till startsidan om användaren skapas framgångsrikt, annars visar felmeddelande
post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if (password == password_confirm)
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/user.db')
    role = 1 # Nya användare som har skapat ett konto och registrerat sig får alltid denna roll
    role = 2 if username == "admin" # Om användaren däremot har registrerats som en administratör kommer rollen att sättas till 2
    db.execute("INSERT INTO user (username,password,role) VALUES (?,?,?)", username, password_digest, role)
    redirect('/')
  else
    "Lösenorden matchade inte!"
  end
end


# Gymloggen visas för inloggade användare. Sessionen kontrolleras för att se vilken roll användaren har och om den är behörig till att se och skapa en gymlog.
# @note Det är användarens roll som avgör vilken gymlog som visas. Om roll är 0 kommer den inte att visas, om den är 1 kommer den att visas och samma sak sker so rollen är 2 vilket är administratör.
# @return [Slim::Template] Renderar användarens gymlog
get('/gymlog') do
  if session[:role_value] == 1
    puts "Användarens roll är: Vanlig"
    db = SQLite3::Database.new("db/user.db")
    db.results_as_hash = true
    @result = db.execute("SELECT * FROM gymlog WHERE \"user-id\"=?", session[:user_id])
    slim(:"gymlog/index")
  elsif session[:role_value] == 2
    puts "Användarens roll är: Administratör"
    db = SQLite3::Database.new("db/user.db")
    db.results_as_hash = true
    @result = db.execute("SELECT * FROM gymlog WHERE \"user-id\"=?", session[:user_id])
    slim(:"gymlog/index")
  else
    puts "Användarens roll är: Gäst"
    slim(:"gymlog/guest")
  end
end


# Raderar en specifik gymlog som användaren väljer
# @param [Integer] id ID för gymloggen som ska raderas
# @return [Redirect] Omdirigerar användaren tillbaka till gymloggen efter borttagning. Gymloggen kommer därmed inte vara synlig längre och den tas bort från databasen.
post('/gymlog/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.execute("DELETE FROM gymlog WHERE id = ?",id)
  redirect('/gymlog')
end


# Visar formuläret för att skapa en ny gymlog
# Denna route kontrollerar först om användaren är inloggad genom att kontrollera sessionen
# Om användaren inte är inloggad och är inloggad som gäst, kommer det att synas ett meddelande tillsammans med en länk där man omdirigeras till inloggningsformuläret när man trycker på den
# Om användaren är inloggad som vanlig användare roll 1 och administratör roll 2 kommer formuläret visas som vanligt
# @return [Redirect] Omdirigerar till '/showlogin' om ingen användare är inloggad
# @return [Slim::Template] Renderar sidan för att skapa en ny gymlog om användaren är inloggad
get('/gymlog/new') do
  if session[:user_id].nil?
    redirect('/showlogin')
  else
    slim(:"gymlog/new")
  end
end


# Skapar en ny gymlog för den inloggade användaren, alltså om roll är antingen 1 eller 2. 
# @param [String] dag Datumet för när träningspasset utfördes
# @param [String] exercise Övningen/övningarna som tränades och därmed loggas
# @return [Redirect] Omdirigerar användaren tillbaka till gymloggen efter skapandet vilket syns i hemsidan.
post('/gymlog/new') do
  dag = params[:dag]
  exercise = params[:exercise]
  user_id = session[:user_id] # Hämtar användarens ID från sessionen

  begin
    db = SQLite3::Database.new("db/user.db")
    db.execute("INSERT INTO gymlog (dag, exercise, \"user-id\") VALUES (?, ?, ?)", dag, exercise, user_id)
    redirect('/gymlog')
  rescue SQLite3::Exception => e
    puts "An error occurred: #{e}"
    redirect('/gymlog/new') # Vid fel, omdirigera tillbaka till sidan för att skapa en ny gymlog
  end
end


# Formuläret visas för att den inloggade användaren skall kunna redigera sin befintliga gymlog som skapades
# @param [Integer] id ID för gymloggen som ska redigeras/uppdateras
# @return [Slim::Template] Renderar redigeringsformuläret för den valda gymloggen
get('/gymlog/:id/edit') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM gymlog WHERE id=?",id).first
  slim(:"gymlog/edit")
end


# Uppdaterar den befintliga gymloggen som den inloggade användaren vill
# @param [Integer] id ID för gymloggen som ska uppdateras
# @param [String] dag Datumet som ska uppdateras i loggen
# @param [String] exercise Övningen som ska uppdateras i loggen
# @return [Redirect] Omdirigerar användaren tillbaka till gymloggen efter uppdateringen
post('/gymlog/:id/update') do
  id = params[:id].to_i
  dag = params[:dag]
  exercise = params[:exercise]
  db = SQLite3::Database.new("db/user.db")
  db.execute("UPDATE gymlog SET dag=?, exercise=? WHERE id = ?", dag, exercise, id)
  redirect('/gymlog')
end


# Lista över alla typer av övningar som administratören har lagt till (types of exercises)
# @return [Slim::Template] Renderar sidan med en lista över övningstyper
get('/type') do
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM type")
  slim(:"type/index2")
end

# GET-sats för att visa en sida för en specifik muskelgrupp och dess övningar när man trycker på den
get('/index2/:type_of') do
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  type_of = params[:type_of].to_i
  @result = db.execute("SELECT * FROM exercise WHERE \"type-id\" = ?", type_of)
  @user_role = session[:role_value]  # Hämta användarens roll från sessionen

  # Kontrollerar om användaren har rollen administratör, roll 2
  if @user_role == 2
    @admin_access = true  
  else
    @admin_access = false  
  end

  slim(:"exercise/index3")
end


# Raderar en specifik övning
# @param [Integer] id ID för övningen som ska raderas
# @return [Redirect] Omdirigerar användaren tillbaka till övningstyperna efter borttagning
post('/exercise/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.execute("DELETE FROM exercise WHERE id = ?",id)
  redirect('/type')
end


# Formuläret för att lägga till en ny övning visas
# @note Kommer enbart visas om användaren har rollen 2, alltså administratör
# @return [Slim::Template] Renderar formuläret för att lägga till en ny övning
get('/exercise/new') do
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM type")
  slim(:"exercise/new2")
end


# Lägger till en ny övning och skickar data för att skapa nya övningar i databasen
# @param [String] exercise Namnet på övningen som ska läggas till
# @param [Integer] type_id ID för typen av övning/muskelgrupp som den tillhör
# @note Endast tillgänglig för administratörer, alltså att rollen är 2
# @return [Redirect] Omdirigerar användaren tillbaka till övningstyperna efter skapandet
post('/exercise/new') do
  exercise = params[:exercise]
  type_id = params['type-id'].to_i  # Använd sträng för att undvika fel på kolumnnamn
  db = SQLite3::Database.new("db/user.db")
  db.execute("INSERT INTO exercise (exercise, \"type-id\") VALUES (?, ?)", exercise, type_id)
  redirect('/type')
end


# Visar formuläret för att redigera en befintlig övning
# @param [Integer] id ID för övningen som ska redigeras
# @note Endast tillgänglig för administratörer, alltså att rollen är 2
# @return [Slim::Template] Renderar redigeringsformuläret för den valda övningen
get('/exercise/:id/edit') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM exercise WHERE id=?",id).first
  slim(:"exercise/edit2")
end


# Uppdaterar en befintlig övning i databasen med den nya datan
# @param [Integer] id ID för övningen som ska uppdateras
# @param [String] exercise Det uppdaterade namnet på övningen
# @note Endast tillgänglig för administratörer, alltså att rollen är 2
# @return [Redirect] Omdirigerar tillbaka till övningstyperna efter att övningen uppdaterats
post('/exercise/:id/update') do
  id = params[:id].to_i
  exercise = params[:exercise]
  db = SQLite3::Database.new("db/user.db")
  db.execute("UPDATE exercise SET exercise=? WHERE id = ?", exercise, id)
  redirect('/type')
end

