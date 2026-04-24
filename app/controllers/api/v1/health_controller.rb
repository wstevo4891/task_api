module Api
  module V1
    class HealthController < ApplicationController
      def show
        render json: {
          status: "healthy",
          timestamp: Time.current.iso8601,
          version: "1.0.0"
        }
      end
    end
  end
end
