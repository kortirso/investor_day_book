# frozen_string_literal: true

describe Portfolios::Cashes::CreateService, type: :service do
  subject(:service_call) { described_class.call(portfolio: portfolio) }

  let!(:portfolio) { create :portfolio }

  describe '.call' do
    it 'succeeds' do
      expect(service_call.success?).to eq true
    end

    it 'and creates cashes' do
      expect { service_call }.to change(portfolio.cashes, :count).by(Cashable::AVAILABLE_CURRENCIES.size * 2)
    end

    it 'and each cash has 0 amount_cents', :aggregate_failures do
      service_call

      Portfolios::Cash.find_each do |cash|
        expect(cash.amount_cents).to eq 0
      end
    end

    it 'and they have different balance param', :aggregate_failures do
      service_call

      expect(Portfolios::Cash.income.size).to eq 2 * Cashable::AVAILABLE_CURRENCIES.size
      expect(Portfolios::Cash.balance.size).to eq 2 * Cashable::AVAILABLE_CURRENCIES.size
    end
  end
end
