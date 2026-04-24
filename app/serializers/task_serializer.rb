class TaskSerializer
  def initialize(task)
    @task = task
  end

  def as_json
    {
      id: @task.id,
      title: @task.title,
      description: @task.description,
      status: @task.status,
      priority: @task.priority,
      due_date: @task.due_date&.iso8601,
      user_id: @task.user_id,
      created_at: @task.created_at.iso8601,
      updated_at: @task.updated_at.iso8601,
      overdue: overdue?,
      days_until_due: days_until_due
    }
  end

  private

  def overdue?
    return false unless @task.due_date
    return false if @task.completed? || @task.cancelled?

    @task.due_date < Time.current
  end

  def days_until_due
    return nil unless @task.due_date

    (@task.due_date.to_date - Date.current).to_i
  end
end
