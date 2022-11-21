# frozen_string_literal: true

class CallbackData < ApplicationRecord
  # TODO: This *really* needs a unique index
  # rubocop:disable Rails/UniqueValidationWithoutIndex
  validates :meeting_id, uniqueness: true
  # rubocop:enable Rails/UniqueValidationWithoutIndex

  serialize :callback_attributes
end
