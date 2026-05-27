# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserTasksQuery do
  let(:user) { create(:user) }
  let(:user_tasks) { user.tasks }

  describe "#call" do
    it "returns a hash with :total and :tasks keys" do
      result = UserTasksQuery.new({}, user_tasks).call(0, 20)
      expect(result).to include(:total, :tasks)
    end

    it "returns tasks as an ActiveRecord::Relation" do
      result = UserTasksQuery.new({}, user_tasks).call(0, 20)
      expect(result[:tasks]).to be_a(ActiveRecord::Relation)
    end

    context "when user has no tasks" do
      it "returns empty tasks" do
        result = UserTasksQuery.new({}, user_tasks).call(0, 20)
        expect(result[:tasks]).to be_empty
      end

      it "returns total of 0" do
        result = UserTasksQuery.new({}, user_tasks).call(0, 20)
        expect(result[:total]).to eq(0)
      end
    end

    context "with offset and limit" do
      before { create_list(:task, 10, user: user) }

      it "applies limit" do
        result = UserTasksQuery.new({}, user_tasks).call(0, 3)
        expect(result[:tasks].size).to eq(3)
      end

      it "applies offset" do
        all_ids = user_tasks.order(created_at: :desc).pluck(:id)
        result = UserTasksQuery.new({}, user_tasks).call(5, 5)
        expect(result[:tasks].pluck(:id)).to match_array(all_ids[5..9])
      end

      it "returns total count of filtered records regardless of offset and limit" do
        result = UserTasksQuery.new({}, user_tasks).call(0, 3)
        expect(result[:total]).to eq(10)
      end

      it "returns empty tasks when offset exceeds total" do
        result = UserTasksQuery.new({}, user_tasks).call(100, 10)
        expect(result[:tasks]).to be_empty
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

    it "returns all tasks when status param is not present" do
      result = UserTasksQuery.new({}, user_tasks).call(0, 20)
      expect(result[:tasks].pluck(:status).uniq.size).to eq(total_statuses)
    end

    it "returns all tasks when status param is blank" do
      result = UserTasksQuery.new({ status: "" }, user_tasks).call(0, 20)
      expect(result[:total]).to eq(total_statuses)
    end

    it "filters by given status" do
      result = UserTasksQuery.new({ status: "completed" }, user_tasks).call(0, 20)
      expect(result[:tasks].pluck(:status).uniq).to eq([ "completed" ])
    end

    it "reflects filtered count in total" do
      result = UserTasksQuery.new({ status: "pending" }, user_tasks).call(0, 20)
      expect(result[:total]).to eq(1)
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

    it "returns all tasks when priority param is not present" do
      result = UserTasksQuery.new({}, user_tasks).call(0, 20)
      expect(result[:tasks].pluck(:priority).uniq.size).to eq(total_priorities)
    end

    it "returns all tasks when priority param is blank" do
      result = UserTasksQuery.new({ priority: "" }, user_tasks).call(0, 20)
      expect(result[:tasks].pluck(:priority).uniq.size).to eq(total_priorities)
    end

    it "filters by given priority" do
      result = UserTasksQuery.new({ priority: "high" }, user_tasks).call(0, 20)
      expect(result[:tasks].pluck(:priority).uniq).to eq([ "high" ])
    end

    it "reflects filtered count in total" do
      result = UserTasksQuery.new({ priority: "high" }, user_tasks).call(0, 20)
      expect(result[:total]).to eq(1)
    end
  end

  describe "filtering by overdue" do
    let!(:overdue_task) { create(:task, user: user, due_date: 1.day.ago) }
    let!(:pending_task) { create(:task, user: user, due_date: 1.day.from_now) }

    context "when overdue param is 'true'" do
      subject { UserTasksQuery.new({ overdue: "true" }, user_tasks).call(0, 20)[:tasks] }

      it { is_expected.to include(overdue_task) }
      it { is_expected.not_to include(pending_task) }
    end

    it "does not filter when overdue param is not present" do
      result = UserTasksQuery.new({}, user_tasks).call(0, 20)
      expect(result[:total]).to eq(user.tasks.count)
    end

    it "does not filter when overdue param is 'false'" do
      result = UserTasksQuery.new({ overdue: "false" }, user_tasks).call(0, 20)
      expect(result[:total]).to eq(user.tasks.count)
    end

    it "does not filter when overdue param is blank" do
      result = UserTasksQuery.new({ overdue: "" }, user_tasks).call(0, 20)
      expect(result[:total]).to eq(user.tasks.count)
    end
  end

  describe "filtering by due_soon" do
    let!(:due_soon_task) { create(:task, user: user, due_date: 1.day.from_now) }
    let!(:future_task) { create(:task, user: user, due_date: 10.days.from_now) }

    context "when due_soon param is 'true'" do
      subject { UserTasksQuery.new({ due_soon: "true" }, user_tasks).call(0, 20)[:tasks] }

      it { is_expected.to include(due_soon_task) }
      it { is_expected.not_to include(future_task) }
    end

    it "does not filter when due_soon param is not present" do
      result = UserTasksQuery.new({}, user_tasks).call(0, 20)
      expect(result[:total]).to eq(user.tasks.count)
    end

    it "does not filter when due_soon param is 'false'" do
      result = UserTasksQuery.new({ due_soon: "false" }, user_tasks).call(0, 20)
      expect(result[:total]).to eq(user.tasks.count)
    end

    it "does not filter when due_soon param is blank" do
      result = UserTasksQuery.new({ due_soon: "" }, user_tasks).call(0, 20)
      expect(result[:total]).to eq(user.tasks.count)
    end
  end

  describe "sorting" do
    task_a_params = { title: "Task A", priority: :high, created_at: 3.days.ago, due_date: 10.days.from_now }
    task_b_params = { title: "Task B", priority: :low, created_at: 2.days.ago, due_date: 5.days.from_now }
    task_c_params = { title: "Task C", priority: :medium, created_at: 1.day.ago, due_date: 15.days.from_now }

    before do
      create(:task, user: user, **task_a_params)
      create(:task, user: user, **task_b_params)
      create(:task, user: user, **task_c_params)
    end

    it "sorts by priority descending when sort is 'priority'" do
      result = UserTasksQuery.new({ sort: "priority" }, user_tasks).call(0, 20)
      expect(result[:tasks].pluck(:priority)).to eq([ "high", "medium", "low" ])
    end

    it "sorts by due_date ascending when sort is 'due_date'" do
      result = UserTasksQuery.new({ sort: "due_date" }, user_tasks).call(0, 20)
      expected = user_tasks.order(:due_date).pluck(:due_date)
      expect(result[:tasks].pluck(:due_date)).to match_array(expected)
    end

    it "sorts by created_at descending when sort is 'created'" do
      result = UserTasksQuery.new({ sort: "created" }, user_tasks).call(0, 20)
      expected = user_tasks.order(created_at: :desc).pluck(:created_at)
      expect(result[:tasks].pluck(:created_at)).to match_array(expected)
    end

    it "defaults to created_at descending when sort param is missing" do
      result = UserTasksQuery.new({}, user_tasks).call(0, 20)
      expected = user_tasks.order(created_at: :desc).pluck(:created_at)
      expect(result[:tasks].pluck(:created_at)).to match_array(expected)
    end

    it "defaults to created_at descending when sort param is invalid" do
      result = UserTasksQuery.new({ sort: "invalid" }, user_tasks).call(0, 20)
      expected = user_tasks.order(created_at: :desc).pluck(:created_at)
      expect(result[:tasks].pluck(:created_at)).to match_array(expected)
    end
  end

  describe "combining filters and sorting" do
    task_a_params = { status: :pending, priority: :high, due_date: 1.day.from_now }
    task_b_params = { status: :pending, priority: :low, due_date: 5.days.from_now }
    task_c_params = { status: :pending, priority: :high, due_date: 1.day.ago }
    task_d_params = { status: :completed, priority: :urgent, due_date: 1.day.ago }

    before do
      create(:task, user: user, **task_a_params)
      create(:task, user: user, **task_b_params)
      create(:task, user: user, **task_c_params)
      create(:task, user: user, **task_d_params)
    end

    context "with one filter and sort" do
      subject { UserTasksQuery.new({ status: "pending", sort: "priority" }, user_tasks).call(0, 20) }

      it "returns correct total for filtered results" do
        expect(subject[:total]).to eq(user_tasks.where(status: "pending").count)
      end

      it "applies status filter" do
        expect(subject[:tasks].pluck(:status).uniq).to eq([ "pending" ])
      end

      it "applies priority sort" do
        expect(subject[:tasks].pluck(:priority)).to eq([ "high", "high", "low" ])
      end
    end

    context "with multiple filters and sort" do
      let(:expected) { user_tasks.where(status: "pending", priority: "high").order(:due_date) }

      subject do
        UserTasksQuery.new({ status: "pending", priority: "high", sort: "due_date" }, user_tasks).call(0, 20)
      end

      it "returns correct total for all applied filters" do
        expect(subject[:total]).to eq(expected.count)
      end

      it "applies status filter" do
        expect(subject[:tasks].pluck(:status).uniq).to eq([ "pending" ])
      end

      it "applies priority filter" do
        expect(subject[:tasks].pluck(:priority).uniq).to eq([ "high" ])
      end

      it "applies due_date sort" do
        expect(subject[:tasks].pluck(:due_date)).to eq(expected.pluck(:due_date))
      end
    end
  end
end
