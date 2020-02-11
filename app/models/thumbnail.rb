# frozen_string_literal: true

class Thumbnail < ApplicationRecord
  belongs_to :playback_format
  default_scope { order(sequence: :asc) }
end
