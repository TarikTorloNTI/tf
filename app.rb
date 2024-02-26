require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'sinatra/reloader'
require 'sinatra/flash'

enable :sessions


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

get('/index2/:type_of') do
  db = SQLite3::Database.new("db/user.db")
  db.results_as_hash = true
  type_of = params[:type_of].to_i
  @result = db.execute("SELECT * FROM exercise WHERE \"type-id\" = ?", type_of)
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
  type_id = params[:type_id].to_i
  db = SQLite3::Database.new("db/user.db")
  db.execute("INSERT INTO exercise (exercise, \"type-id\" VALUES (?, ?)", exercise, type_id)
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

