class User < ApplicationRecord
  belongs_to :team, optional: true
  belongs_to :player, optional: true

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  # Define the roles enum with string values
  enum role: {
    player: 'player',
    coach: 'coach',
    fan: 'fan',
    admin: 'admin'
  }, _default: 'fan'

  # Methods
  def player?
    role == 'player'
  end
end
