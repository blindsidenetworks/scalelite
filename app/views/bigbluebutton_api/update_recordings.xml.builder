# frozen_string_literal: true

xml.response do
  xml.returncode 'SUCCESS'
  xml.updated @updated.to_s
end
