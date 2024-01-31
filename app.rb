require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

get('/') do
    slim(:start)
end


get ('/gymlog') do
    db = SQLite3::Database.new("db/user.db")
    result = db.execute('SELECT * FROM gymlog')
    db.results_as_hash = true
    p result
    p "Hello"
  end
  

# get('/gymlog/new') do
#     slim(:gymlog/new)
# end