module Api
  module V1
    class AuthenticationController < ApplicationController
      # POST /api/v1/auth/register
      def register
        user = User.create!(user_params)
        token = JsonWebToken.encode(user_id: user.id)
        data = {
          message: "Account created successfully",
          user: UserSerializer.new(user).as_json,
          token: token
        }

        render json: data, status: :created
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by!(email: params[:email].downcase)

        if user.authenticate(params[:password])
          token = JsonWebToken.encode(user_id: user.id)
          data = {
            message: "Login successful",
            user: UserSerializer.new(user).as_json,
            token: token
          }

          render json: data
        else
          raise ExceptionHandler::AuthenticationError, "Invalid credentials"
        end
      rescue ActiveRecord::RecordNotFound
        raise ExceptionHandler::AuthenticationError, "Invalid credentials"
      end

      private

      def user_params
        params.permit(:email, :password, :password_confirmation, :name)
      end
    end
  end
end
