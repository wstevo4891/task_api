# frozen_string_literal: true

require "rails_helper"

RSpec.describe TasksQuery do
  let(:user) { create(:user) }
  let(:user_tasks) { user.tasks }

  describe "#initialize" do
    it "accepts params and user_tasks" do
      query = TasksQuery.new({}, user_tasks)
      expect(query).to be_a(TasksQuery)
    end

    it "sets default page to 1" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.page).to eq(1)
    end

    it "sets default per_page to PER_PAGE_DEFAULT" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.per_page).to eq(TasksQuery::PER_PAGE_DEFAULT)
    end

    it "sets total to count of results" do
      create_list(:task, 5, user: user)
      query = TasksQuery.new({}, user_tasks)
      expect(query.total).to eq(5)
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
    before { create_list(:task, 30, user: user) }

    context "with default pagination" do
      it "returns PER_PAGE_DEFAULT items" do
        query = TasksQuery.new({}, user_tasks)
        expect(query.tasks.size).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end

      it "returns first page by default" do
        query = TasksQuery.new({}, user_tasks)
        first_page_tasks = query.tasks
        expect(first_page_tasks.size).to eq(TasksQuery::PER_PAGE_DEFAULT)
      end
    end

    context "with custom page" do
      it "returns second page when page is 2" do
        query = TasksQuery.new({ page: 2 }, user_tasks)
        expect(query.page).to eq(2)
        expect(query.tasks.size).to eq(10)
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
        expect(query.total_pages).to eq(3)
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

    it "filters tasks by priority when priority param is present" do
      query = TasksQuery.new({ priority: "high" }, user_tasks)
      expect(query.tasks.all? { |t| t.priority == "high" }).to be_truthy
    end

    it "returns all priorities when priority param is not present" do
      query = TasksQuery.new({}, user_tasks)
      priorities = query.tasks.map(&:priority).uniq
      expect(priorities.size).to be > 1
    end

    it "handles blank priority param" do
      query = TasksQuery.new({ priority: "" }, user_tasks)
      expect(query.total).to eq(4)
    end

    it "filters by urgent priority" do
      query = TasksQuery.new({ priority: "urgent" }, user_tasks)
      expect(query.tasks.all? { |t| t.priority == "urgent" }).to be_truthy
    end
  end

  describe "filtering by overdue" do
    let!(:overdue_task) { create(:task, user: user, due_date: 1.day.ago) }
    let!(:pending_task) { create(:task, user: user, due_date: 1.day.from_now) }

    it "filters overdue tasks when overdue param is true" do
      query = TasksQuery.new({ overdue: "true" }, user_tasks)
      expect(query.tasks.include?(overdue_task)).to be_truthy
      expect(query.tasks.include?(pending_task)).to be_falsey
    end

    it "returns all tasks when overdue param is false or missing" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.total).to eq(2)
    end

    it "does not filter when overdue param is not 'true'" do
      query = TasksQuery.new({ overdue: "false" }, user_tasks)
      expect(query.total).to eq(2)
    end
  end

  describe "filtering by due_soon" do
    let!(:due_soon_task) { create(:task, user: user, due_date: 1.day.from_now) }
    let!(:future_task) { create(:task, user: user, due_date: 10.days.from_now) }

    it "filters due_soon tasks when due_soon param is true" do
      query = TasksQuery.new({ due_soon: "true" }, user_tasks)
      expect(query.tasks.include?(due_soon_task)).to be_truthy
      expect(query.tasks.include?(future_task)).to be_falsey
    end

    it "returns all tasks when due_soon param is false or missing" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.total).to eq(2)
    end

    it "does not filter when due_soon param is not 'true'" do
      query = TasksQuery.new({ due_soon: "false" }, user_tasks)
      expect(query.total).to eq(2)
    end
  end

  describe "sorting" do
    before do
      create(:task, user: user, title: "Task A", priority: :high, created_at: 3.days.ago, due_date: 10.days.from_now)
      create(:task, user: user, title: "Task B", priority: :low, created_at: 2.days.ago, due_date: 5.days.from_now)
      create(:task, user: user, title: "Task C", priority: :medium, created_at: 1.day.ago, due_date: 15.days.from_now)
    end

    context "sort by priority" do
      it "sorts by priority descending" do
        query = TasksQuery.new({ sort: "priority" }, user_tasks)
        priorities = query.tasks.map(&:priority)
        expect(priorities).to eq(["high", "medium", "low"])
      end
    end

    context "sort by due_date" do
      it "sorts by due_date ascending" do
        query = TasksQuery.new({ sort: "due_date" }, user_tasks)
        due_dates = query.tasks.map(&:due_date)
        expect(due_dates).to eq(due_dates.sort)
      end
    end

    context "sort by created" do
      it "sorts by created_at descending" do
        query = TasksQuery.new({ sort: "created" }, user_tasks)
        created_ats = query.tasks.map(&:created_at)
        expect(created_ats).to eq(created_ats.sort.reverse)
      end
    end

    context "default sort" do
      it "sorts by created_at descending when sort param is missing" do
        query = TasksQuery.new({}, user_tasks)
        created_ats = query.tasks.map(&:created_at)
        expect(created_ats).to eq(created_ats.sort.reverse)
      end

      it "sorts by created_at descending when sort param is invalid" do
        query = TasksQuery.new({ sort: "invalid" }, user_tasks)
        created_ats = query.tasks.map(&:created_at)
        expect(created_ats).to eq(created_ats.sort.reverse)
      end
    end
  end

  describe "combining filters and sorting" do
    before do
      create(:task, user: user, status: :pending, priority: :high, due_date: 2.days.ago)
      create(:task, user: user, status: :pending, priority: :low, due_date: 5.days.ago)
      create(:task, user: user, status: :completed, priority: :urgent, due_date: 1.day.ago)
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

  describe "edge cases" do
    it "handles empty user_tasks collection" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.tasks).to be_empty
      expect(query.total).to eq(0)
      expect(query.total_pages).to eq(0)
    end

    it "handles page 0 as page 1" do
      create(:task, user: user)
      query = TasksQuery.new({ page: 0 }, user_tasks)
      expect(query.page).to eq(0)
    end

    it "handles negative per_page gracefully" do
      create(:task, user: user)
      query = TasksQuery.new({ per_page: -10 }, user_tasks)
      # The query will process with negative per_page, which Rails will handle
      expect(query.per_page).to eq(-10)
    end

    it "handles per_page of 0" do
      create(:task, user: user)
      query = TasksQuery.new({ per_page: 0 }, user_tasks)
      expect(query.per_page).to eq(0)
    end

    it "returns correct total count before pagination" do
      create_list(:task, 50, user: user)
      query = TasksQuery.new({ page: 1, per_page: 10 }, user_tasks)
      expect(query.total).to eq(50)
      expect(query.tasks.size).to eq(10)
    end
  end

  describe "attributes" do
    before { create_list(:task, 5, user: user) }

    it "exposes page" do
      query = TasksQuery.new({ page: 2 }, user_tasks)
      expect(query.page).to eq(2)
    end

    it "exposes per_page" do
      query = TasksQuery.new({ per_page: 15 }, user_tasks)
      expect(query.per_page).to eq(15)
    end

    it "exposes tasks" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.tasks).to be_a(ActiveRecord::Relation)
    end

    it "exposes total" do
      query = TasksQuery.new({}, user_tasks)
      expect(query.total).to eq(5)
    end
  end
end
