# frozen_string_literal: true

class Tenant < ApplicationRecord
  SECRETS_SEPARATOR = ':'

  validates :name, presence: true
  validates :secrets, presence: true

  validates :name, uniqueness: true
  validates :secrets, uniqueness: true

  has_many :custom_settings, dependent: :destroy, class_name: 'TenantSettings'

  def secrets_array
    secrets.split(SECRETS_SEPARATOR)
  end
end
