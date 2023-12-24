# frozen_string_literal: true

FactoryBot.define do
  factory :tenant_setting do
    sequence(:param) { |n| "param-#{n}" }
    value { 'value' }
    override { 'false' }
    tenant_id {}
  end
end
