# frozen_string_literal: true

class TenantSettings < ApplicationRecord
  # White list of allowed settings
  # Possible setting types:
  # Numeric,
  # Array
  ALLOWED_SETTINGS = {
    published_days: :numeric,
    maxNumPages: :numeric,
    video_formats: ['webm', 'mp4'],
    autoStartRecording: ['true', 'false'],
    allowStartStopRecording: ['true, false'],
    muteOnStart: ['true', 'false'],
    defaultGuestPolicy: ['ALWAYS_ACCEPT', 'NEVER_ACCEPT']
  }

  belongs_to :tenant

  validates :name, presence: true
  validates :value, presence: true

  validates :name, uniqueness: true

  validate :validate_name
  validate :validate_value

  private
  def validate_name
    # Validate that given name symbol is whitelisted
    unless ALLOWED_SETTINGS[self.name.to_sym].present?
      errors.add(:name,"Setting name #{self.name} is not permitted")
    end
  end

  def validate_value

  end
end
