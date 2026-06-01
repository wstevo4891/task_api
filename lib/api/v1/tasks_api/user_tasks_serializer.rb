# frozen_string_literal: true

module Api
  module V1
    module TasksApi
      # ToDo: Add a spec for this class
      class UserTasksSerializer
        def initialize(paginator, data, serializer = TaskSerializer)
          @paginator = paginator
          @total = data[:total]
          @tasks = data[:tasks]
          @serializer = serializer
        end

        def as_json
          {
            tasks: task_json,
            pagination: pagination_json(total)
          }
        end

        private

        attr_reader :paginator, :total, :tasks, :serializer

        delegate :pagination_json, to: :paginator

        def task_json
          tasks.map { |task| serializer.call(task) }
        end
      end
    end
  end
end
