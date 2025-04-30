class Team < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :level, presence: true
  validates :classification, numericality: { only_integer: true }
end
