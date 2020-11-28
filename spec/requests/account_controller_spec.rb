# frozen_string_literal: true

describe AccountController, type: :request do
  describe 'GET#index' do
    context 'for not logged user' do
      it 'redirects to login page' do
        get account_index_path
        follow_redirect!

        expect(last_response.body).to include('Log in')
      end
    end

    context 'for logged user' do
      context 'for unconfirmed user' do
        let!(:user) { create :user, :unconfirmed }

        it 'renders english setup page' do
          post user_session_path(user: { email: user.email, password: user.password })
          follow_redirect!

          get account_index_path
          follow_redirect!

          expect(last_response.body).to include('Log in')
        end
      end

      context 'for confirmed user' do
        let!(:user) { create :user }

        before do
          post user_session_path(user: { email: user.email, password: user.password })
          follow_redirect!
        end

        it 'renders english setup page' do
          get account_index_en_path

          expect(last_response.body).to include('Add portfolio')
        end

        it 'renders russian setup page' do
          get account_index_ru_path

          expect(last_response.body).to include('Добавить портфель')
        end
      end
    end
  end
end
