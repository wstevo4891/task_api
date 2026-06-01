# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserTasksQuery do
  let(:user) { create(:user) }
  let(:user_tasks) { user.tasks }
  let(:params) { {} }
  let(:offset) { 0 }
  let(:limit) { 20 }

  subject { UserTasksQuery.new(params, user_tasks).call(offset, limit) }

  describe "#call" do
    it "returns a hash with :total and :tasks keys" do
      expect(subject).to include(:total, :tasks)
    end

    it "returns tasks as an ActiveRecord::Relation" do
      expect(subject[:tasks]).to be_a(ActiveRecord::Relation)
    end

    context "when user has no tasks" do
      it "returns empty tasks" do
        expect(subject[:tasks]).to be_empty
      end

      it "returns total of 0" do
        expect(subject[:total]).to eq(0)
      end
    end

    context "with offset and limit" do
      before { create_list(:task, 10, user: user) }

      context "with limit of 3" do
        let(:limit) { 3 }

        it "applies limit" do
          expect(subject[:tasks].size).to eq(3)
        end

        it "returns total count of filtered records regardless of offset and limit" do
          expect(subject[:total]).to eq(10)
        end
      end

      context "with offset 5 and limit 5" do
        let(:offset) { 5 }
        let(:limit) { 5 }

        it "applies offset" do
          all_ids = user_tasks.order(created_at: :desc).pluck(:id)
          expect(subject[:tasks].pluck(:id)).to match_array(all_ids[5..9])
        end
      end

      context "when offset exceeds total" do
        let(:offset) { 100 }
        let(:limit) { 10 }

        it "returns empty tasks" do
          expect(subject[:tasks]).to be_empty
        end
      end
    end
  end

  describe "filtering by status" do
    let(:total_statuses) { Task.statuses.size }

    before do
      create(:task, :pending, user: user)
      create(:task, :in_progress, user: user)
      create(:task, :completed, user: user)
      create(:task, :cancelled, user: user)
    end

    context "when status param is not present" do
      it "returns all tasks" do
        expect(subject[:tasks].pluck(:status).uniq.size).to eq(total_statuses)
      end
    end

    context "when status param is blank" do
      let(:params) { { status: "" } }

      it "returns all tasks" do
        expect(subject[:total]).to eq(total_statuses)
      end
    end

    context "when status param is 'completed'" do
      let(:params) { { status: "completed" } }

      it "filters by given status" do
        expect(subject[:tasks].pluck(:status).uniq).to eq([ "completed" ])
      end
    end

    context "when status param is 'pending'" do
      let(:params) { { status: "pending" } }

      it "reflects filtered count in total" do
        expect(subject[:total]).to eq(1)
      end
    end
  end

  describe "filtering by priority" do
    let(:total_priorities) { Task.priorities.size }

    before do
      create(:task, :low_priority, user: user)
      create(:task, :medium_priority, user: user)
      create(:task, :high_priority, user: user)
      create(:task, :urgent_priority, user: user)
    end

    context "when priority param is not present" do
      it "returns all tasks" do
        expect(subject[:tasks].pluck(:priority).uniq.size).to eq(total_priorities)
      end
    end

    context "when priority param is blank" do
      let(:params) { { priority: "" } }

      it "returns all tasks" do
        expect(subject[:tasks].pluck(:priority).uniq.size).to eq(total_priorities)
      end
    end

    context "when priority param is 'high'" do
      let(:params) { { priority: "high" } }

      it "filters by given priority" do
        expect(subject[:tasks].pluck(:priority).uniq).to eq([ "high" ])
      end

      it "reflects filtered count in total" do
        expect(subject[:total]).to eq(1)
      end
    end
  end

  describe "filtering by overdue" do
    let!(:overdue_task) { create(:task, user: user, due_date: 1.day.ago) }
    let!(:pending_task) { create(:task, user: user, due_date: 1.day.from_now) }

    context "when overdue param is 'true'" do
      let(:params) { { overdue: "true" } }

      it "includes overdue tasks" do
        expect(subject[:tasks]).to include(overdue_task)
      end

      it "excludes non-overdue tasks" do
        expect(subject[:tasks]).not_to include(pending_task)
      end
    end

    context "when overdue param is not present" do
      it "does not filter" do
        expect(subject[:total]).to eq(user.tasks.count)
      end
    end

    context "when overdue param is 'false'" do
      let(:params) { { overdue: "false" } }

      it "does not filter" do
        expect(subject[:total]).to eq(user.tasks.count)
      end
    end

    context "when overdue param is blank" do
      let(:params) { { overdue: "" } }

      it "does not filter" do
        expect(subject[:total]).to eq(user.tasks.count)
      end
    end
  end

  describe "filtering by due_soon" do
    let!(:due_soon_task) { create(:task, user: user, due_date: 1.day.from_now) }
    let!(:future_task) { create(:task, user: user, due_date: 10.days.from_now) }

    context "when due_soon param is 'true'" do
      let(:params) { { due_soon: "true" } }

      it "includes due soon tasks" do
        expect(subject[:tasks]).to include(due_soon_task)
      end

      it "excludes future tasks" do
        expect(subject[:tasks]).not_to include(future_task)
      end
    end

    context "when due_soon param is not present" do
      it "does not filter" do
        expect(subject[:total]).to eq(user.tasks.count)
      end
    end

    context "when due_soon param is 'false'" do
      let(:params) { { due_soon: "false" } }

      it "does not filter" do
        expect(subject[:total]).to eq(user.tasks.count)
      end
    end

    context "when due_soon param is blank" do
      let(:params) { { due_soon: "" } }

      it "does not filter" do
        expect(subject[:total]).to eq(user.tasks.count)
      end
    end
  end

  describe "sorting" do
    task_a_params = { priority: :high, created_at: 3.days.ago, due_date: 10.days.from_now }
    task_b_params = { priority: :low, created_at: 2.days.ago, due_date: 5.days.from_now }
    task_c_params = { priority: :medium, created_at: 1.day.ago, due_date: 15.days.from_now }

    before do
      create(:task, user: user, **task_a_params)
      create(:task, user: user, **task_b_params)
      create(:task, user: user, **task_c_params)
    end

    context "when sort is 'priority'" do
      let(:params) { { sort: "priority" } }

      it "sorts by priority descending" do
        expect(subject[:tasks].pluck(:priority)).to eq([ "high", "medium", "low" ])
      end
    end

    context "when sort is 'due_date'" do
      let(:params) { { sort: "due_date" } }

      it "sorts by due_date ascending" do
        expected = user_tasks.order(:due_date).pluck(:due_date)
        expect(subject[:tasks].pluck(:due_date)).to match_array(expected)
      end
    end

    context "when sort is 'created'" do
      let(:params) { { sort: "created" } }

      it "sorts by created_at descending" do
        expected = user_tasks.order(created_at: :desc).pluck(:created_at)
        expect(subject[:tasks].pluck(:created_at)).to match_array(expected)
      end
    end

    context "when sort param is missing" do
      it "defaults to created_at descending" do
        expected = user_tasks.order(created_at: :desc).pluck(:created_at)
        expect(subject[:tasks].pluck(:created_at)).to match_array(expected)
      end
    end

    context "when sort param is invalid" do
      let(:params) { { sort: "invalid" } }

      it "defaults to created_at descending" do
        expected = user_tasks.order(created_at: :desc).pluck(:created_at)
        expect(subject[:tasks].pluck(:created_at)).to match_array(expected)
      end
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
      let(:params) { { status: "pending", sort: "priority" } }

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
      let(:params) { { status: "pending", priority: "high", sort: "due_date" } }
      let(:expected) { user_tasks.where(status: "pending", priority: "high").order(:due_date) }

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
