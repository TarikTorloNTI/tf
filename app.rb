require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'sinatra/flash'

enable :sessions

#Fixa inner joins
#Fixa admin behörighet att role = 2
#Gäst ska inte ha någon behörighet att redigera eller ta bort övningarna i se övningar
#Vanlig användare (role = 1) ska kunna se/ha sin gymlog och även se alla övningar men inte redigera/ta bort
#Admin (role = 2) ska kunna göra allt detta och därmed om admin ändrar någonting i se övningar är det synligt för alla användare 
#Fixa CSS
#Fixa också så att man kan logga ut

get('/') do
    slim(:start, layout: :login_layout)
end


get('/showlogin') do
  slim(:login, layout: :login_layout)
end

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
    session[:role_value] = role.to_i  # Konvertera rollen till en siffra
    puts "Användarens roll är: #{role_name}"
    redirect '/start_login'
  else
    "FEL LÖSEN!"
  end
end



get('/guest_login') do
  session[:role_value] = 0 # Sätt rollen till 0 för gästanvändaren
  redirect('/start_login')
end



get('/todos') do 
  id = session[:id].to_i
  db = SQLite3::Database.new('db/user.db')
  db.results_as_hash = true
  result = db.execute("SELECT * FROM user WHERE user_id = ?",id)
  p "Alla todos från result #{result}"
  slim(:"todos/index",locals:{todos:result})
end


get('/start_login') do 
  slim(:loggedin)
end

# get('/guest_log')
#   session[:user_id] = nil 
#   session[:role] = 0 
# end

post('/users/new') do
  username = params[:username]
  password = params[:password]
  password_confirm = params[:password_confirm]

  if (password == password_confirm)
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/user.db')
    role = 1 # Standard roll för nya användare
    role = 2 if username == "admin" # Om användaren registreras som "admin", sätt roll till 2
    db.execute("INSERT INTO user (username,password,role) VALUES (?,?,?)", username, password_digest, role)
    redirect('/')
  else
    "Lösenorden matchade inte!"
  end
end

# För att hantera administratörsbehörigheter när du bygger administratörsfunktioner
def admin_required!
  redirect '/start_login' unless session[:role_value] == 2
end

# Exempel på användning av admin_required!-metoden för att begränsa åtkomst till administratörsfunktioner
get '/admin_dashboard' do
  admin_required!
  slim :admin_dashboard
end





def current_user_id
  @user_id
end


get('/gymlog') do
  if session[:role_value] == 1
    puts "Användarens roll är: Vanlig"
    db = SQLite3::Database.new("db/user.db")
    db.results_as_hash = true
    @result = db.execute("SELECT * FROM gymlog WHERE \"user-id\"=?", session[:user_id])
    slim(:"gymlog/index")
  else
    puts "Användarens roll är: Gäst"
    slim(:"gymlog/guest")
  end
end





post('/gymlog/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.execute("DELETE FROM gymlog WHERE id = ?",id)
  redirect('/gymlog')
end


get('/gymlog/new') do
  if session[:user_id].nil?
    redirect('/showlogin')
  else
    slim(:"gymlog/new")
  end
end


post('/gymlog/new') do
  dag = params[:dag]
  exercise = params[:exercise]
  user_id = session[:user_id] # Hämta användarens ID från sessionen

  begin
    db = SQLite3::Database.new("db/user.db")
    db.execute("INSERT INTO gymlog (dag, exercise, \"user-id\") VALUES (?, ?, ?)", dag, exercise, user_id)
    redirect('/gymlog')
  rescue SQLite3::Exception => e
    puts "An error occurred: #{e}"
    redirect('/gymlog/new') # Vid fel, omdirigera tillbaka till sidan för att skapa en ny gymlog
  end
end





get('/gymlog/:id/edit') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM gymlog WHERE id=?",id).first
  slim(:"gymlog/edit")
end

post('/gymlog/:id/update') do
  id = params[:id].to_i
  dag = params[:dag]
  exercise = params[:exercise]
  db = SQLite3::Database.new("db/user.db")
  db.execute("UPDATE gymlog SET dag=?, exercise=? WHERE id = ?", dag, exercise, id)
  redirect('/gymlog')
end


get('/type') do
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM type")
  slim(:"type/index2")
end

# GET-rutin för att visa sidan för en specifik muskelgrupp och dess övningar
get '/index2/:type_of' do
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  type_of = params[:type_of].to_i
  @result = db.execute("SELECT * FROM exercise WHERE \"type-id\" = ?", type_of)
  @user_role = session[:role_value]  # Hämta användarens roll från sessionen

  # Kontrollera om användaren är administratör (roll = 2)
  if @user_role == 2
    @admin_access = true  # Visa knappar för redigering, borttagning och lägg till ny övning
  else
    @admin_access = false  # Dölj knappar för användare med andra roller
  end

  slim(:"exercise/index3")
end



post('/exercise/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.execute("DELETE FROM exercise WHERE id = ?",id)
  redirect('/type')
end



get('/exercise/new') do
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM type")
  slim(:"exercise/new2")
end



post('/exercise/new') do
  exercise = params[:exercise]
  type_id = params['type-id'].to_i  # Använd sträng för att undvika fel på kolumnnamn
  db = SQLite3::Database.new("db/user.db")
  db.execute("INSERT INTO exercise (exercise, \"type-id\") VALUES (?, ?)", exercise, type_id)
  redirect('/type')
end








get('/exercise/:id/edit') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  @result = db.execute("SELECT * FROM exercise WHERE id=?",id).first
  slim(:"exercise/edit2")
end

post('/exercise/:id/update') do
  id = params[:id].to_i
  exercise = params[:exercise]
  db = SQLite3::Database.new("db/user.db")
  db.execute("UPDATE exercise SET exercise=? WHERE id = ?", exercise, id)
  redirect('/type')
end

