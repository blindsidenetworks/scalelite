# frozen_string_literal: true

class ChangeRecordings < ActiveRecord::Migration[6.1]
  def up
    change_column_null :recordings, :publish_updated, false

    change_column_null :recordings, :protected, false
    change_column_default :recordings, :protected, from: nil, to: false

    change_column_null :recordings, :published, false
    change_column_default :recordings, :published, from: nil, to: false
  end
end
