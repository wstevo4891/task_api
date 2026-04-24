module ExceptionHandler
  extend ActiveSupport::Concern

  # Custom exception classes
  class AuthenticationError < StandardError; end
  class ExpiredToken < StandardError; end
  class InvalidToken < StandardError; end

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_intity

    rescue_from ExceptionHandler::AuthenticationError, with: :unauthorized

    rescue_from ExceptionHandler::ExpiredToken, with: :unauthorized

    rescue_from ExceptionHandler::InvalidToken, with: :unauthorized
  end

  private

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def unauthorized(exception)
    render json: { error: exception.message }, status: :unauthorized
  end
end
