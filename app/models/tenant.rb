# frozen_string_literal: true

class Tenant < ApplicationRecord
  validates :name, presence: true
  validates :secrets, presence: true

  validates :name, uniqueness: true
  validates :secrets, uniqueness: true
end
