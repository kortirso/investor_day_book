# frozen_string_literal: true

module Quotes
  module Collection
    module Saving
      class TinkoffService
        prepend BasicService

        def call(data:)
          data.each { |element| process_data(element) }
        end

        private

        def process_data(data)
          find_or_create_security(data)
            .then { |security| data.merge(security_id: security.id) }
            .then { |data| find_or_initialize_quote(data) }
            .then { |quote| update_quote(quote, data) }
        end

        def find_or_create_security(data)
          attrs = data[:security_data].slice(:ticker, :type, :isin)
          Security.find_or_create_by(attrs) do |object|
            object.name = data.dig(:security_data, :name)
          end
        end

        def find_or_initialize_quote(data)
          attrs = data[:quote_data].slice(:price_currency).merge(security_id: data[:security_id])
          Quote.find_or_initialize_by(attrs) do |object|
            object.source           = Sourceable::TINKOFF
            object.face_value_cents = data.dig(:quote_data, :face_value_cents)
          end
        end

        def update_quote(quote, data)
          quote.price = data.dig(:quote_data, :price)
          quote.figi = data.dig(:quote_data, :figi) if quote.figi.nil?
          quote.save
        end
      end
    end
  end
end
