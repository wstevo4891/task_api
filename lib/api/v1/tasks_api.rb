# frozen_string_literal: true

module Api
  module V1
    module TasksApi
      def self.user_tasks(user, params)
        paginator = Paginator.new(params[:pagination])
        query = UserTasksQuery.new(params[:query], user.tasks)
        results = query.call(paginator.page_offset, paginator.per_page)

        UserTasksSerializer.new(paginator, results).as_json
      end
    end
  end
end
