class Team < ApplicationRecord
  has_many :users, dependent: :restrict_with_error

  validates :name, presence: true,
                  uniqueness: { case_sensitive: false },
                  length: { minimum: 2, maximum: 50 }
  validates :level, presence: true
  validates :classification, numericality: { only_integer: true }
end
