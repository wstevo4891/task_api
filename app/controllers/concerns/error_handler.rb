module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  end

  private

  def handle_standard_error(exception)
    # Log the error for debugging
    Rails.logger.error("Unhandled error: #{exception.message}")
    Rails.logger.error(exception.backtrace.first(10).join("\n"))

    render json: {
      error: {
        code: "internal_error",
        message: Rails.env.production? ? "An unexpected error occurred" : exception.message
      }
    }, status: :internal_server_error
  end

  def handle_not_found(exception)
    render json: {
      error: {
        code: "not_found",
        message: "Resource not found: #{exception.message}"
      }
    }, status: :not_found
  end

  def handle_validation_error(exception)
    render json: {
      error: {
        code: "validation_failed",
        message: "Validation failed",
        details: exception.record.errors.messages
      }
    }, status: :unprocessable_entity
  end

  def handle_parameter_missing(exception)
    render json: {
      error: {
        code: "missing_parameter",
        message: exception.message
      }
    }, status: :bad_request
  end
end
