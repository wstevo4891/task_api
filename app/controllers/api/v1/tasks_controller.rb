module Api
  module V1
    class TasksController < ApplicationController
      before_action :authenticate_request
      before_action :set_task, only: [ :show, :update, :destroy ]

      # GET /api/v1/tasks
      def index
        tasks = current_user.tasks

        # Apply filters
        tasks = tasks.where(status: params[:status]) if params[:status].present?
        tasks = tasks.where(priority: params[:priority]) if params[:priority].present?
        tasks = tasks.overdue if params[:overdue] == "true"
        tasks = tasks.due_soon if params[:due_soon] == "true"

        # Apply sorting
        tasks = case params[:sort]
        when "priority"
          tasks.by_priority
        when "due_date"
          tasks.order(:due_date)
        when "created"
          tasks.order(created_at: :desc)
        else
          tasks.order(created_at: :desc)
        end

        # Pagination
        page = (params[:page] || 1).to_i
        per_page = [ (params[:per_page] || 20).to_i, 100 ].min
        total = tasks.count
        tasks = tasks.offset((page - 1) * per_page).limit(per_page)

        render json: {
          tasks: tasks.map { |t| TaskSerializer.new(t).as_json },
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: (total.to_f / per_page).ceil,
            total_count: total
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
