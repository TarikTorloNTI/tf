require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'

enable :sessions
user-id = 1
user-id = session[:key1].to_i


get('/') do
    slim(:start)
end


get('/gymlog') do
    db = SQLite3::Database.new("db/user.db")
    db.results_as_hash = true
    @result = db.execute("SELECT * FROM gymlog")

    slim(:"gymlog/index")
end


post('/gymlog/:id/delete') do
  id = params[:id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.execute("DELETE FROM gymlog WHERE id = ?",id)
  redirect('/gymlog')
end


get('/gymlog/new') do
  slim(:"gymlog/new")
end


post('/gymlog/new') do
  dag = params[:dag]
  exercise = params[:exercise].to_i
  db = SQLite3::Database.new("db/user.db")
  db.execute("INSERT INTO gymlog (dag, exercise) VALUES (?,?)", dag, exercise)
  redirect('/gymlog')
end