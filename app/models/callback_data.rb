# frozen_string_literal: true

class CallbackData < ApplicationRecord
  validates :meeting_id, uniqueness: true

  serialize :callback_attributes
end
