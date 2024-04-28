require 'sqlite3'
require 'bcrypt'
module Model


# En klass som representerar en användare i systemet. Hanterar autentisering och rollkontroll.
class User
  attr_reader :username, :role

  # Konstruerar en ny användare.
  # @param username [String] användarens användarnamn
  # @param password_digest [String] hashat lösenord för användaren
  # @param role [Integer] användarens roll i systemet
  def initialize(username, password_digest, role)
    @username = username
    @password_digest = password_digest
    @role = role
  end
end

  # Autentiserar en användare baserat på ett lösenord.
  # @param password [String] lösenordet som ska verifieras mot det hashade lösenordet
  # @return [Boolean] sant om lösenordet matchar det lagrade hashade lösenordet, annars falskt
  def authenticate(password)
    BCrypt::Password.new(@password_digest) == password
  end
end

# Klassen representerar en gymlogg i systemet, hanterar data och interaktioner relaterade till gymloggar.
class Gymlog
  attr_reader :id, :user_id, :dag, :exercise

  # Initialiserar en ny Gymlog.
  # @param id [Integer] ID för loggen, nil för nya loggar som inte sparats än.
  # @param user_id [Integer] ID för användaren som äger loggen.
  # @param dag [Date] Datumet för gymloggen.
  # @param exercise [String] Beskrivning av övningen.
  def initialize(id, user_id, dag, exercise)
    @id = id
    @user_id = user_id
    @dag = dag
    @exercise = exercise
  end

  # Sparar loggen till databasen.
  def save
    if id
      # Uppdatera befintlig logg
    else
      # Skapa ny logg
    end
  end
end

# Klassen representerar en övning i systemet, hanterar data och interaktioner relaterade till övningar.
class Exercise
  attr_reader :id, :type_id, :exercise

  # Initialiserar en ny övning.
  # @param id [Integer] ID för övningen, nil för nya övningar som inte sparats än.
  # @param type_id [Integer] ID för övningstypen som övningen tillhör.
  # @param exercise [String] Namn eller beskrivning av övningen.
  def initialize(id, type_id, exercise)
    @id = id
    @type_id = type_id
    @exercise = exercise
  end

  # Sparar övningen till databasen. Skapar en ny post om den inte finns, annars uppdaterar.
  def save
    if id.nil?
      # Skapa ny post
    else
      # Uppdatera befintlig post
    end
  end

  # Uppdaterar detaljer för en befintlig övning.
  def update_attributes(attributes)
    # Uppdatera attribut för övningen
  end
end