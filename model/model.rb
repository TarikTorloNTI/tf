require 'sqlite3'
require 'bcrypt'
module Model


# Registrerar en användare baserat på användarnamn och lösenord.
# @param [String] username Användarnamnet för registrering i databasen.
# @param [String] password Lösenordet för registrering i databasen.
# @return [Hash, nil] Lägger till användaresn detaljer om registreringen och autentiseringen fungerar, annars nil.
def self.authenticate_user(username, password)
    db = db_connection
    user = db.execute("SELECT * FROM user WHERE username = ?", [username]).first
    return nil unless user

    if BCrypt::Password.new(user["password"]) == password
      user
    else
      nil
    end
end
  

# Skapar en ny användare i databasen.
# @param [String] username Användarnamnet.
# @param [String] password Lösenordet.
# @param [String] password_confirm Lösenordsbekräftelse.
# @return [Boolean] True om användaren lyckades skapas, annars false.
def self.create_user(username, password, password_confirm)
    return false unless password == password_confirm

    db = db_connection
    password_digest = BCrypt::Password.create(password)
    begin
      db.execute("INSERT INTO user (username, password, role) VALUES (?, ?, ?)", [username, password_digest, 1])
      true
    rescue
      false
    end
end
  

# Loggar ut användaren genom att rensa sessionen.
def self.logout_user
end 


# Hämtar alla gymloggar för en specifik användare.
# @param [Integer] user_id Användarens roll/session.
# @return [Array<Hash>] En lista över alla gymloggar associerade med användaren.
def self.get_gymlogs_for_user(user_id)
    db = db_connection
    db.execute("SELECT * FROM gymlog WHERE user_id = ?", [user_id])
end


# Lägger till en ny gymlogg för en användare.
# @param [Integer] user_id Användarens ID.
# @param [String] dag Datumet för gymloggen.
# @param [String] exercise Övningen som loggades.
# @return [Boolean] True om gymloggen skapades, annars false.
def self.add_gymlog(user_id, dag, exercise)
    db = db_connection
    begin
      db.execute("INSERT INTO gymlog (user_id, dag, exercise) VALUES (?, ?, ?)", [user_id, dag, exercise])
      true
    rescue
      false
    end
end

# Uppdaterar en befintlig gymlogg.
# @param [Integer] log_id Gymloggens ID.
# @param [String] dag Det nya datumet för gymloggen.
# @param [String] exercise Den uppdaterade övningen.
# @return [Boolean] True om gymloggen uppdaterades, annars false.
def self.update_gymlog(gymlog_id, dag, exercise)
    db = db_connection
    begin
      db.execute("UPDATE gymlog SET dag = ?, exercise = ? WHERE gymlog_id = ?", [dag, exercise, gymlog_id])
      true
    rescue
      false
    end
end

# Raderar en specifik gymlogg.
# @param [Integer] log_id Gymloggens unika ID.
# @return [Boolean] True om gymloggen raderades, annars false.
def self.delete_gymlog(log_id)
    db = db_connection
    begin
      db.execute("DELETE FROM gymlog WHERE id = ?", [log_id])
      true
    rescue
      false
    end
end

# Hämtar en lista över alla övningstyper.
# @return [Array<Hash>] En lista över alla övningstyper.
def self.get_exercise_types
    db = db_connection
    db.execute("SELECT * FROM type")
end

# Lägger till en ny övning.
# @param [String] exercise Namnet på övningen.
# @param [Integer] type_id ID för övningstypen övningen tillhör.
# @return [Boolean] True om övningen skapades, annars false.
def self.add_exercise(exercise, type_id)
    db = db_connection
    begin
      db.execute("INSERT INTO exercise (exercise, type_id) VALUES (?, ?)", [exercise, type_id])
      true
    rescue
      false
    end
end

# Uppdaterar en befintlig övning.
# @param [Integer] exercise_id Övningens ID.
# @param [String] new_exercise Det uppdaterade namnet på övningen.
# @return [Boolean] True om övningen uppdaterades, annars false.
def self.update_exercise(exercise_id, new_exercise)
    db = db_connection
    begin
      db.execute("UPDATE exercise SET exercise = ? WHERE id = ?", [new_exercise, exercise_id])
      true
    rescue
      false
    end
end

# Raderar en specifik övning.
# @param [Integer] exercise_id Övningens ID.
# @return [Boolean] True om övningen raderades framgångsrikt, annars false.
def self.delete_exercise(exercise_id)
    db = db_connection
    begin
      db.execute("DELETE FROM exercise WHERE id = ?", [exercise_id])
      true
    rescue
      false
    end
end

end