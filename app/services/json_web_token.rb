# frozen_string_literal: true

class JsonWebToken
  HMAC_SHA256 = "HS256"

  # Use Rails secret key for signing tokens
  SECRET_KEY = Rails.application.credentials.secret_key_base.to_s

  class << self
    # Encode payload with expiration time
    def encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      JWT.encode(payload, SECRET_KEY, HMAC_SHA256)
    end

    # Decode and verify token
    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, algorithm: HMAC_SHA256)
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      raise ExceptionHandler::ExpiredToken, "Token has expired"
    rescue JWT::DecodeError
      raise ExceptionHandler::InvalidToken, "Invalid token"
    end
  end
end
