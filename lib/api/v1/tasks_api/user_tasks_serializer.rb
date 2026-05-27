# frozen_string_literal: true

module Api
  module V1
    module TasksApi
      class UserTasksSerializer
        def initialize(paginator, data, serializer = TaskSerializer)
          @paginator = paginator
          @total = data[:total]
          @tasks = data[:tasks]
          @serializer = serializer
        end

        def as_json
          {
            tasks: task_data,
            pagination: pagination_data
          }
        end

        private

        attr_reader :paginator, :total, :tasks, :serializer

        delegate :page, :per_page, :page_offset, :total_pages, to: :paginator

        def task_data
          tasks.map { |task| serializer.call(task) }
        end

        def pagination_data
          {
            current_page: page,
            per_page: per_page,
            total_pages: total_pages(total),
            total_count: total
          }
        end
      end
    end
  end
end
