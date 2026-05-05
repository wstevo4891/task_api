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

    it "sets given page param" do
      query = TasksQuery.new({ page: 2 }, user_tasks)
      expect(query.page).to eq(2)
    end

    it "sets given per_page param" do
      query = TasksQuery.new({ per_page: 15 }, user_tasks)
      expect(query.per_page).to eq(15)
    end

    context "with empty params" do
      subject { TasksQuery.new({}, user_tasks) }

      it "sets default page to 1" do
        expect(subject.page).to eq(1)
      end

      it "sets default per_page to PER_PAGE_DEFAULT" do
        expect(subject.per_page).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end

      it "sets total to count of results" do
        create_list(:task, 5, user: user)
        expect(subject.total).to eq(5)
      end
    end

    describe "edge cases" do
      context "when user has no tasks" do
        subject { TasksQuery.new({}, user_tasks) }

        it { expect(subject.tasks).to be_empty }

        it { expect(subject.total).to eq(0) }

        it { expect(subject.total_pages).to eq(0) }
      end

      it "handles page 0 as page 1" do
        query = TasksQuery.new({ page: 0 }, user_tasks)
        expect(query.page).to eq(1)
      end

      it "handles negative page as page 1" do
        query = TasksQuery.new({ page: -1 }, user_tasks)
        expect(query.page).to eq(1)
      end

      it "handles negative per_page as PER_PAGE_DEFAULT" do
        query = TasksQuery.new({ per_page: -10 }, user_tasks)
        expect(query.per_page).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end

      it "handles per_page of 0 as PER_PAGE_DEFAULT" do
        query = TasksQuery.new({ per_page: 0 }, user_tasks)
        expect(query.per_page).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end
    end
  end

  describe "#total_pages" do
    it "calculates total pages correctly" do
      create_list(:task, 25, user: user)
      query = TasksQuery.new({}, user_tasks)
      expect(query.total_pages).to eq(2)
    end

    it "returns 1 when total is less than per_page" do
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

  describe "pagination" do
    before { create_list(:task, 50, user: user) }

    context "with default pagination" do
      subject { TasksQuery.new({}, user_tasks) }

      it "returns PER_PAGE_DEFAULT items" do
        expect(subject.tasks.size).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end

      it "returns first page by default" do
        expect(subject.page).to eq(1)
      end
    end

    context "with custom page" do
      it "returns second page when page is 2" do
        query = TasksQuery.new({ page: 2 }, user_tasks)
        expect(query.page).to eq(2)
      end

      it "returns empty collection for out of range page" do
        query = TasksQuery.new({ page: 100 }, user_tasks)
        expect(query.tasks).to be_empty
      end

      it "converts string page to integer" do
        query = TasksQuery.new({ page: "2" }, user_tasks)
        expect(query.page).to eq(2)
      end
    end

    context "with custom per_page" do
      it "returns custom per_page amount" do
        query = TasksQuery.new({ per_page: 10 }, user_tasks)
        expect(query.per_page).to eq(10)
        expect(query.tasks.size).to eq(10)
      end

      it "caps per_page at PER_PAGE_MAXIMUM" do
        query = TasksQuery.new({ per_page: 500 }, user_tasks)
        expect(query.per_page).to eq(TasksQuery::PER_PAGE_MAXIMUM)
      end

      it "converts string per_page to integer" do
        query = TasksQuery.new({ per_page: "15" }, user_tasks)
        expect(query.per_page).to eq(15)
      end

      it "uses custom per_page in pagination" do
        query = TasksQuery.new({ per_page: 10 }, user_tasks)
        expect(query.tasks.size).to eq(10)
        expect(query.total_pages).to eq(5)
      end

      it "returns correct total count before pagination" do
        query = TasksQuery.new({ page: 1, per_page: 10 }, user_tasks)
        expect(query.total).to eq(50)
        expect(query.tasks.size).to eq(10)
      end
    end
  end

  describe "filtering by status" do
    before do
      create(:task, user: user, status: :pending)
      create(:task, user: user, status: :in_progress)
      create(:task, user: user, status: :completed)
    end

    it "filters tasks by status when status param is present" do
      query = TasksQuery.new({ status: "pending" }, user_tasks)
      expect(query.tasks.all? { |t| t.status == "pending" }).to be_truthy
    end

    it "returns all statuses when status param is not present" do
      query = TasksQuery.new({}, user_tasks)
      statuses = query.tasks.map(&:status).uniq
      expect(statuses.size).to be > 1
    end

    it "handles blank status param" do
      query = TasksQuery.new({ status: "" }, user_tasks)
      expect(query.total).to eq(3)
    end

    it "filters by completed status" do
      query = TasksQuery.new({ status: "completed" }, user_tasks)
      expect(query.tasks.all? { |t| t.status == "completed" }).to be_truthy
    end
  end

  describe "filtering by priority" do
    before do
      create(:task, user: user, priority: :low)
      create(:task, user: user, priority: :medium)
      create(:task, user: user, priority: :high)
      create(:task, user: user, priority: :urgent)
    end

    context "when priority param is present" do
      subject { TasksQuery.new({ priority: "high" }, user_tasks) }

      it "returns tasks with selected priority" do
        expect(subject.tasks.all? { |t| t.priority == "high" }).to be_truthy
      end

      it "does not return tasks with non-selected priorities" do
        [ "low", "medium", "urgent" ].each do |value|
          expect(subject.tasks.all? { |t| t.priority == value }).to be_falsy
        end
      end
    end

    it "returns all priorities when priority param is not present" do
      query = TasksQuery.new({}, user_tasks)
      priorities = query.tasks.map(&:priority).uniq
      expect(priorities.size).to eq(Task.priorities.size)
    end

    it "handles blank priority param" do
      query = TasksQuery.new({ priority: "" }, user_tasks)
      expect(query.total).to eq(user.tasks.count)
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
      expect(query.total).to eq(2)
    end

    it "does not filter when due_soon param is false" do
      query = TasksQuery.new({ due_soon: "false" }, user_tasks)
      expect(query.total).to eq(2)
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
        priorities = query.tasks.map(&:priority)
        expect(priorities).to eq([ "high", "medium", "low" ])
      end
    end

    describe "by due_date" do
      it "sorts tasks by due_date in ascending order" do
        query = TasksQuery.new({ sort: "due_date" }, user_tasks)
        due_dates = query.tasks.map(&:due_date)
        expect(due_dates).to eq(due_dates.sort)
      end
    end

    describe "by created" do
      it "sorts tasks by created_at in descending order" do
        query = TasksQuery.new({ sort: "created" }, user_tasks)
        created_ats = query.tasks.map(&:created_at)
        expect(created_ats).to eq(created_ats.sort.reverse)
      end
    end

    context "when sort param is missing" do
      it "sorts by created_at in descending order" do
        query = TasksQuery.new({}, user_tasks)
        created_ats = query.tasks.map(&:created_at)
        expect(created_ats).to eq(created_ats.sort.reverse)
      end
    end

    context "when sort param is invalid" do
      it "sorts by created_at in descending order" do
        query = TasksQuery.new({ sort: "invalid" }, user_tasks)
        created_ats = query.tasks.map(&:created_at)
        expect(created_ats).to eq(created_ats.sort.reverse)
      end
    end
  end

  describe "combining filters and sorting" do
    task_a_params = {
      status: :pending,
      priority: :high,
      due_date: 2.days.ago
    }

    task_b_params = {
      status: :pending,
      priority: :low,
      due_date: 5.days.ago
    }

    task_c_params = {
      status: :completed,
      priority: :urgent,
      due_date: 1.day.ago
    }

    before do
      create(:task, user: user, **task_a_params)
      create(:task, user: user, **task_b_params)
      create(:task, user: user, **task_c_params)
    end

    it "applies filters and then sorts" do
      query = TasksQuery.new({ status: "pending", sort: "priority" }, user_tasks)
      expect(query.total).to eq(2)
      priorities = query.tasks.map(&:priority)
      expect(priorities.first).to eq("high")
    end

    it "applies multiple filters and sorts" do
      query = TasksQuery.new({ status: "pending", priority: "high", sort: "due_date" }, user_tasks)
      expect(query.total).to eq(1)
      expect(query.tasks.first.priority).to eq("high")
    end
  end
end
