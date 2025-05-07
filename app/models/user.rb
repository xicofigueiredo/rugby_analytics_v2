class User < ApplicationRecord
  belongs_to :team, optional: true
  belongs_to :player, optional: true

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[player coach fan admin] }
  validates :email, presence: true, uniqueness: true

  enum role: { user: 0, admin: 1 }

  # Methods
  def player?
    role == 'player'
  end
end
