# frozen_string_literal: true

class Tenant < ApplicationRecord
  validates :name, presence: true
  validates :secret, presence: true

  validates :name, uniqueness: true
  validates :secret, uniqueness: true
end
