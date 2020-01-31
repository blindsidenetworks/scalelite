# frozen_string_literal: true

require 'test_helper'

class ServerTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Server.new
  end
end
