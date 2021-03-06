# frozen_string_literal: true

FactoryBot.define do
  factory :bond, parent: :security, class: 'Bond' do
    type { 'Bond' }
    name { { en: 'Yandex Bond', ru: 'Яндекс Облигация' } }
  end
end
