# frozen_string_literal: true

describe Portfolios::Cash, type: :model do
  it 'factory should be valid' do
    portfolios_cash = build :portfolios_cash

    expect(portfolios_cash).to be_valid
  end

  describe 'associations' do
    it { is_expected.to belong_to :portfolio }
  end

  it { is_expected.to monetize(:amount) }
end
