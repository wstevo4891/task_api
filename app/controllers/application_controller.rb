class ApplicationController < ActionController::API
  include ErrorHandler
  include ExceptionHandler

  # Make current_user available to all controllers
  attr_reader :current_user

  private

  # Authenticate user from Authorization header
  def authenticate_request
    @current_user = authorize_request
  end

  def authorize_request
    header = request.headers["Authorization"]
    raise ExceptionHandler::AuthenticationError, "Missing token" unless header

    token = header.split(" ").last
    decoded = JsonWebToken.decode(token)
    User.find(decoded[:user_id])
  end
end
