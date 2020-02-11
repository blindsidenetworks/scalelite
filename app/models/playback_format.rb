# frozen_string_literal: true

class PlaybackFormat < ApplicationRecord
  belongs_to :recording
  has_many :thumbnails, dependent: :destroy
  default_scope { order(format: :asc) }
end
