# frozen_string_literal: true

module Api
  module V1
    class TasksController < ApplicationController
      before_action :authenticate_request
      before_action :set_task, only: [ :show, :update, :destroy ]

      # GET /api/v1/tasks
      def index
        result = TasksApi.user_tasks(current_user, query_params)
        render json: result, status: :ok
      end

      # GET /api/v1/tasks/:id
      def show
        render json: { task: TaskSerializer.call(@task) }
      end

      # POST /api/v1/tasks
      def create
        @task = current_user.tasks.create!(task_params)
        render json: { task: TaskSerializer.call(@task) }, status: :created
      end

      # PATCH/PUT /api/v1/tasks/:id
      def update
        @task.update!(task_params)
        render json: { task: TaskSerializer.call(@task) }
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
        render json: { task: TaskSerializer.call(@task) }
      end

      private

      def set_task
        @task = current_user.tasks.find(params[:id])
      end

      def query_params
        {
          pagination: params.permit(:page, :per_page),
          query: params.permit(:status, :priority, :due_soon, :overdue, :sort)
        }
      end

      def task_params
        params.permit(:title, :description, :status, :priority, :due_date)
      end
    end
  end
end
