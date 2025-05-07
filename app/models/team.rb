class Team < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :players

  validates :name, presence: true,
                  uniqueness: { case_sensitive: false },
                  length: { minimum: 2, maximum: 50 }
  validates :level, presence: true
  validates :classification, numericality: { only_integer: true }
  # validates :abbreviation, presence: true, length: { minimum: 2, maximum: 5 }
  # validates :main_color, presence: true
  # validates :secondary_color, presence: true
end
