# frozen_string_literal: true

class TenantSettings < ApplicationRecord
  belongs_to :tenant

  validates :name, presence: true
  validates :value, presence: true

  validates :name, uniqueness: true
end
