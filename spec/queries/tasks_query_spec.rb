# frozen_string_literal: true

require "rails_helper"

RSpec.describe TasksQuery do
  let(:user) { create(:user) }
  let(:user_tasks) { user.tasks }

  describe "#initialize" do
    it "accepts params hash and tasks list" do
      query = TasksQuery.new({}, user_tasks)
      expect(query).to be_a(TasksQuery)
    end

    it "retrieves tasks from database" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.tasks).to be_a(ActiveRecord::Relation)
    end

    context "with empty params" do
      subject { TasksQuery.new({}, user_tasks) }

      it "sets default page to 1" do
        expect(subject.page).to eq(1)
      end

      it "sets default per_page to PER_PAGE_DEFAULT" do
        expect(subject.per_page).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end

      it "sets total to count of all user tasks" do
        create_list(:task, 5, user: user)
        expect(subject.total).to eq(5)
      end
    end

    context "with given params" do
      subject { TasksQuery.new({ page: 2, per_page: 5 }, user_tasks) }

      it { expect(subject.page).to eq(2) }

      it { expect(subject.per_page).to eq(5) }
    end

    describe "edge cases" do
      context "when user has no tasks" do
        subject { TasksQuery.new({}, user_tasks) }

        it { expect(subject.tasks).to be_empty }

        it { expect(subject.total).to eq(0) }
      end

      it "handles page 0 as page 1" do
        query = TasksQuery.new({ page: 0 }, user_tasks)
        expect(query.page).to eq(1)
      end

      it "handles negative page as page 1" do
        query = TasksQuery.new({ page: -10 }, user_tasks)
        expect(query.page).to eq(1)
      end

      it "converts string page to integer" do
        query = TasksQuery.new({ page: "2" }, user_tasks)
        expect(query.page).to eq(2)
      end

      it "handles per_page of 0 as PER_PAGE_DEFAULT" do
        query = TasksQuery.new({ per_page: 0 }, user_tasks)
        expect(query.per_page).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end

      it "handles negative per_page as PER_PAGE_DEFAULT" do
        query = TasksQuery.new({ per_page: -10 }, user_tasks)
        expect(query.per_page).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end

      it "converts string per_page to integer" do
        query = TasksQuery.new({ per_page: "10" }, user_tasks)
        expect(query.per_page).to eq(10)
      end

      it "caps per_page at PER_PAGE_MAXIMUM" do
        query = TasksQuery.new({ per_page: 500 }, user_tasks)
        expect(query.per_page).to eq(TasksQuery::PER_PAGE_MAXIMUM)
      end
    end
  end

  describe "#total_pages" do
    it "defaults to 1 when user has no tasks" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.total_pages).to eq(1)
    end

    context "with default per_page" do
      it "returns 1 when total is less than default" do
        create_list(:task, 5, user: user)
        query = TasksQuery.new({}, user_tasks)
        expect(query.total_pages).to eq(1)
      end

      it "rounds up for partial pages" do
        create_list(:task, 21, user: user)
        query = TasksQuery.new({}, user_tasks)
        expect(query.total_pages).to eq(2)
      end
    end

    context "with per_page param" do
      it "calculates total pages correctly" do
        create_list(:task, 25, user: user)
        query = TasksQuery.new({ per_page: 5 }, user_tasks)
        expect(query.total_pages).to eq(5)
      end

      it "returns 1 when total is less than per_page" do
        create_list(:task, 5, user: user)
        query = TasksQuery.new({ per_page: 10 }, user_tasks)
        expect(query.total_pages).to eq(1)
      end

      it "rounds up for partial pages" do
        create_list(:task, 11, user: user)
        query = TasksQuery.new({ per_page: 5 }, user_tasks)
        expect(query.total_pages).to eq(3)
      end
    end
  end

  describe "pagination" do
    before { create_list(:task, 50, user: user) }

    context "with page param" do
      it "returns expected results for given page" do
        query = TasksQuery.new({ page: 2 }, user_tasks)

        expected = user_tasks
          .order(created_at: :desc)
          .offset(TasksQuery::PER_PAGE_DEFAULT)
          .limit(TasksQuery::PER_PAGE_DEFAULT)
          .pluck(:id)

        expect(query.tasks.pluck(:id)).to match_array(expected)
      end

      it "returns empty collection for out of range page" do
        query = TasksQuery.new({ page: 100 }, user_tasks)
        expect(query.tasks).to be_empty
      end
    end

    context "with per_page param" do
      it "returns expected number of tasks" do
        query = TasksQuery.new({ per_page: 10 }, user_tasks)
        expect(query.tasks.size).to eq(10)
      end

      it "returns expected results" do
        query = TasksQuery.new({ page: 2, per_page: 10 }, user_tasks)

        expected = user_tasks
          .order(created_at: :desc)
          .offset(10)
          .limit(10)
          .pluck(:id)

        expect(query.tasks.pluck(:id)).to match_array(expected)
      end
    end
  end

  describe "filtering by status" do
    let(:total_statuses) { Task.statuses.size }

    before do
      create(:task, user: user, status: :pending)
      create(:task, user: user, status: :in_progress)
      create(:task, user: user, status: :completed)
      create(:task, user: user, status: :cancelled)
    end

    it "returns all statuses when status param is not present" do
      query = TasksQuery.new({}, user_tasks)
      statuses = query.tasks.pluck(:status).uniq
      expect(statuses.size).to eq(total_statuses)
    end

    it "returns all statuses when status param is blank" do
      query = TasksQuery.new({ status: "" }, user_tasks)
      expect(query.total).to eq(total_statuses)
    end

    it "filters by given status param" do
      query = TasksQuery.new({ status: "completed" }, user_tasks)
      statuses = query.tasks.pluck(:status).uniq
      expect(statuses.first).to eq("completed")
    end
  end

  describe "filtering by priority" do
    let(:total_priorities) { Task.priorities.size }

    before do
      create(:task, user: user, priority: :low)
      create(:task, user: user, priority: :medium)
      create(:task, user: user, priority: :high)
      create(:task, user: user, priority: :urgent)
    end

    it "returns all priorities when priority param is not present" do
      query = TasksQuery.new({}, user_tasks)
      priorities = query.tasks.pluck(:priority).uniq
      expect(priorities.size).to eq(total_priorities)
    end

    it "returns all priorities when priority param is blank" do
      query = TasksQuery.new({ priority: "" }, user_tasks)
      priorities = query.tasks.pluck(:priority).uniq
      expect(priorities.size).to eq(total_priorities)
    end

    it "filters by given priority param" do
      query = TasksQuery.new({ priority: "high" }, user_tasks)
      priorities = query.tasks.pluck(:priority).uniq
      expect(priorities.first).to eq("high")
    end
  end

  describe "filtering by overdue" do
    let!(:overdue_task) { create(:task, user: user, due_date: 1.day.ago) }
    let!(:pending_task) { create(:task, user: user, due_date: 1.day.from_now) }

    context "when overdue param is true" do
      subject { TasksQuery.new({ overdue: "true" }, user_tasks).tasks }

      it { is_expected.to include(overdue_task) }

      it { is_expected.not_to include(pending_task) }
    end

    it "does not filter when overdue param is not present" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.total).to eq(user.tasks.count)
    end

    it "does not filter when overdue param is false" do
      query = TasksQuery.new({ overdue: "false" }, user_tasks)
      expect(query.total).to eq(user.tasks.count)
    end

    it "does not filter when overdue param is blank" do
      query = TasksQuery.new({ overdue: "" }, user_tasks)
      expect(query.total).to eq(user.tasks.count)
    end
  end

  describe "filtering by due_soon" do
    let!(:due_soon_task) { create(:task, user: user, due_date: 1.day.from_now) }
    let!(:future_task) { create(:task, user: user, due_date: 10.days.from_now) }

    context "when due_soon param is true" do
      subject { TasksQuery.new({ due_soon: "true" }, user_tasks).tasks }

      it { is_expected.to include(due_soon_task) }

      it { is_expected.not_to include(future_task) }
    end

    it "returns all tasks when due_soon param is not present" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.total).to eq(user.tasks.count)
    end

    it "does not filter when due_soon param is false" do
      query = TasksQuery.new({ due_soon: "false" }, user_tasks)
      expect(query.total).to eq(user.tasks.count)
    end

    it "does not filter when due_soon param is blank" do
      query = TasksQuery.new({ due_soon: "" }, user_tasks)
      expect(query.total).to eq(user.tasks.count)
    end
  end

  describe "sorting" do
    task_a_params = {
      title: "Task A",
      priority: :high,
      created_at: 3.days.ago,
      due_date: 10.days.from_now
    }

    task_b_params = {
      title: "Task B",
      priority: :low,
      created_at: 2.days.ago,
      due_date: 5.days.from_now
    }

    task_c_params = {
      title: "Task C",
      priority: :medium,
      created_at: 1.day.ago,
      due_date: 15.days.from_now
    }

    before do
      create(:task, user: user, **task_a_params)
      create(:task, user: user, **task_b_params)
      create(:task, user: user, **task_c_params)
    end

    describe "by priority" do
      it "sorts tasks by priority in descending order" do
        query = TasksQuery.new({ sort: "priority" }, user_tasks)
        priorities = query.tasks.pluck(:priority)
        expect(priorities).to eq([ "high", "medium", "low" ])
      end
    end

    describe "by due_date" do
      it "sorts tasks by due_date in ascending order" do
        query = TasksQuery.new({ sort: "due_date" }, user_tasks)
        actual = query.tasks.pluck(:due_date)
        expected = user_tasks.order(:due_date).pluck(:due_date)
        expect(actual).to match_array(expected)
      end
    end

    describe "by created" do
      it "sorts tasks by created_at in descending order" do
        query = TasksQuery.new({ sort: "created" }, user_tasks)
        actual = query.tasks.pluck(:created_at)
        expected = user_tasks.order(created_at: :desc).pluck(:created_at)
        expect(actual).to match_array(expected)
      end
    end

    context "when sort param is missing" do
      it "sorts by created_at in descending order" do
        query = TasksQuery.new({}, user_tasks)
        actual = query.tasks.pluck(:created_at)
        expected = user_tasks.order(created_at: :desc).pluck(:created_at)
        expect(actual).to match_array(expected)
      end
    end

    context "when sort param is invalid" do
      it "sorts by created_at in descending order" do
        query = TasksQuery.new({ sort: "invalid" }, user_tasks)
        actual = query.tasks.pluck(:created_at)
        expected = user_tasks.order(created_at: :desc).pluck(:created_at)
        expect(actual).to match_array(expected)
      end
    end
  end

  describe "combining filters and sorting" do
    task_a_params = {
      status: :pending,
      priority: :high,
      due_date: 1.day.from_now
    }

    task_b_params = {
      status: :pending,
      priority: :low,
      due_date: 5.days.from_now
    }

    task_c_params = {
      status: :pending,
      priority: :high,
      due_date: 1.day.ago
    }

    task_d_params = {
      status: :completed,
      priority: :urgent,
      due_date: 1.day.ago
    }

    before do
      create(:task, user: user, **task_a_params)
      create(:task, user: user, **task_b_params)
      create(:task, user: user, **task_c_params)
      create(:task, user: user, **task_d_params)
    end

    context "with one filter" do
      subject { TasksQuery.new({ status: "pending", sort: "priority" }, user_tasks) }

      it "returns expected total" do
        expected = user_tasks.where(status: "pending").by_priority
        expect(subject.total).to eq(expected.count)
      end

      it "applies expected filter" do
        statuses = subject.tasks.pluck(:status).uniq
        expect(statuses).to eq([ "pending" ])
      end

      it "applies expected sorting" do
        priorities = subject.tasks.pluck(:priority)
        expect(priorities).to eq([ "high", "high", "low" ])
      end
    end

    context "with multiple filters" do
      let(:expected) do
        user_tasks.where(status: "pending", priority: "high").order(:due_date)
      end

      subject do
        TasksQuery.new({ status: "pending", priority: "high", sort: "due_date" }, user_tasks)
      end

      it "returns expected total" do
        expect(subject.total).to eq(expected.count)
      end

      it "applies first filter" do
        statuses = subject.tasks.pluck(:status).uniq
        expect(statuses).to eq([ "pending" ])
      end

      it "applies second filter" do
        priorities = subject.tasks.pluck(:priority).uniq
        expect(priorities).to eq([ "high" ])
      end

      it "applies expected sorting" do
        dates = subject.tasks.pluck(:due_date)
        expect(dates).to eq(expected.pluck(:due_date))
      end
    end
  end
end
