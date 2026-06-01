# frozen_string_literal: true

module Api
  module V1
    module TasksApi
      class UserTasksCache
        attr_reader :key

        def initialize(user_id, params, paginator)
          @user_id = user_id
          @params = params
          @per_page = paginator.per_page
          @page = paginator.page
          @key = generate_cache_key
        end

        def fetch(&block)
          Rails.cache.fetch(key, expires_in: 1.hour) do
            Rails.logger.info "--- Cache Miss! Fetching data for user tasks ---"
            block.call
          end
        end

        private

        attr_reader :user_id, :params, :per_page, :page

        def generate_cache_key
          cache_key = "user-tasks/#{user_id}/"
          cache_key += "#{params[:status]}/" if params[:status].present?
          cache_key += "#{params[:priority]}/" if params[:priority].present?
          cache_key += "overdue/" if params[:overdue] == "true"
          cache_key += "due_soon/" if params[:due_soon] == "true"
          cache_key += "#{params[:sort]}/" if params[:sort].present?

          "#{cache_key}per_page=#{per_page}/page=#{page}"
        end
      end
    end
  end
end
