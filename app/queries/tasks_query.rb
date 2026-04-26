# frozen_string_literal: true

class TasksQuery
  PER_PAGE_DEFAULT = 20
  PER_PAGE_MAXIMUM = 100

  attr_reader :page, :per_page, :tasks, :total

  def initialize(params, user_tasks)
    @params = params
    @page = (params[:page] || 1).to_i
    @per_page = calc_per_page
    @tasks = process_query(user_tasks)
  end

  def total_pages
    (total.to_f / per_page).ceil
  end

  private

  attr_reader :params

  def calc_per_page
    current = (params[:per_page] || PER_PAGE_DEFAULT).to_i
    [ current, PER_PAGE_MAXIMUM ].min
  end

  def process_query(user_tasks)
    user_tasks = apply_filters(user_tasks)
    user_tasks = apply_sorting(user_tasks)
    @total = user_tasks.count

    user_tasks.offset((page - 1) * per_page).limit(per_page)
  end

  def apply_filters(user_tasks)
    user_tasks = user_tasks.where(status: params[:status]) if params[:status].present?
    user_tasks = user_tasks.where(priority: params[:priority]) if params[:priority].present?
    user_tasks = user_tasks.overdue if params[:overdue] == "true"
    user_tasks = user_tasks.due_soon if params[:due_soon] == "true"
    user_tasks
  end

  def apply_sorting(user_tasks)
    case params[:sort]
    when "priority"
      user_tasks.by_priority
    when "due_date"
      user_tasks.order(:due_date)
    when "created"
      user_tasks.order(created_at: :desc)
    else
      user_tasks.order(created_at: :desc)
    end
  end
end

# def index
#   tasks = current_user.tasks

#   # Apply filters
#   tasks = tasks.where(status: params[:status]) if params[:status].present?
#   tasks = tasks.where(priority: params[:priority]) if params[:priority].present?
#   tasks = tasks.overdue if params[:overdue] == "true"
#   tasks = tasks.due_soon if params[:due_soon] == "true"

#   # Apply sorting
#   tasks = case params[:sort]
#   when "priority"
#     tasks.by_priority
#   when "due_date"
#     tasks.order(:due_date)
#   when "created"
#     tasks.order(created_at: :desc)
#   else
#     tasks.order(created_at: :desc)
#   end

#   # Pagination
#   page = (params[:page] || 1).to_i
#   per_page = [ (params[:per_page] || 20).to_i, 100 ].min
#   total = tasks.count
#   tasks = tasks.offset((page - 1) * per_page).limit(per_page)

#   render json: {
#     tasks: tasks.map { |t| TaskSerializer.new(t).as_json },
#     pagination: {
#       current_page: page,
#       per_page: per_page,
#       total_pages: (total.to_f / per_page).ceil,
#       total_count: total
#     }
#   }
# end
