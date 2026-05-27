# frozen_string_literal: true

class UserTasksQuery
  True = "true"

  def initialize(params, user_tasks)
    @params = params
    @scope = user_tasks
  end

  def call(offset, limit)
    result = @scope
    result = filter_by_status(result)
    result = filter_by_priority(result)
    result = filter_by_due_date(result)
    result = apply_sorting(result)

    {
      total: result.count,
      tasks: result.offset(offset).limit(limit)
    }
  end

  private

  attr_reader :params

  def filter_by_status(relation)
    return relation unless params[:status].present?

    relation.where(status: params[:status])
  end

  def filter_by_priority(relation)
    return relation unless params[:priority].present?

    relation.where(priority: params[:priority])
  end

  def filter_by_due_date(relation)
    relation = relation.overdue if params[:overdue] == True

    relation = relation.due_soon if params[:due_soon] == True

    relation
  end

  def apply_sorting(relation)
    case params[:sort]
    when "priority"
      relation.by_priority
    when "due_date"
      relation.order(:due_date)
    when "created"
      relation.order(created_at: :desc)
    else
      relation.order(created_at: :desc)
    end
  end
end
