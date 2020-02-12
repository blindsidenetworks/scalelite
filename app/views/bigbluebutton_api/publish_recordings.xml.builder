# frozen_string_literal: true

xml.response do
  xml.returncode 'SUCCESS'
  xml.published @published.to_s
end
