module Api
  module V1
    class TasksController < ApplicationController
      before_action :authenticate_request
      before_action :set_task, only: [ :show, :update, :destroy ]

      # GET /api/v1/tasks
      def index
        results = TasksQuery.new(params, current_user.tasks)

        render json: {
          tasks: results.tasks.map { |t| TaskSerializer.new(t).as_json },
          pagination: {
            current_page: results.page,
            per_page: results.per_page,
            total_pages: results.total_pages,
            total_count: results.total
          }
        }
      end

      # GET /api/v1/tasks/:id
      def show
        render json: { task: TaskSerializer.new(@task).as_json }
      end

      # POST /api/v1/tasks
      def create
        task = current_user.tasks.create!(task_params)
        render json: { task: TaskSerializer.new(task).as_json }, status: :created
      end

      # PATCH/PUT /api/v1/tasks/:id
      def update
        @task.update!(task_params)
        render json: { task: TaskSerializer.new(@task).as_json }
      end

      # DELETE /api/v1/tasks/:id
      def destroy
        @task.destroy
        head :no_content
      end

      # POST /api/v1/tasks/:id/complete
      def complete
        set_task
        @task.update!(status: :completed)
        render json: { task: TaskSerializer.new(@task).as_json }
      end

      private

      def set_task
        @task = current_user.tasks.find(params[:id])
      end

      def task_params
        params.permit(:title, :description, :status, :priority, :due_date)
      end
    end
  end
end
