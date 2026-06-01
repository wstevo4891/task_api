# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::TasksApi do
  let(:user) { create(:user) }
  let(:params) { { query: {}, pagination: {} } }

  describe ".user_tasks" do
    subject { described_class.user_tasks(user, params) }

    it "returns a hash with :tasks and :pagination keys" do
      expect(subject).to include(:tasks, :pagination)
    end

    it "returns tasks serialized as an array of hashes" do
      create(:task, user: user)
      expect(subject[:tasks]).to be_an(Array)
      expect(subject[:tasks].first).to include(:id, :title, :status)
    end

    it "returns only tasks belonging to the given user" do
      other_user = create(:user)
      own_task = create(:task, user: user)
      create(:task, user: other_user)

      expect(subject[:tasks].map { |t| t[:id] }).to contain_exactly(own_task.id)
    end

    describe "caching" do
      it "delegates to UserTasksCache#fetch" do
        expect_any_instance_of(Api::V1::TasksApi::UserTasksCache)
          .to receive(:fetch)
          .and_call_original

        subject
      end

      it "returns cached result without re-querying on cache hit" do
        cached_result = { tasks: [], pagination: {} }

        allow_any_instance_of(Api::V1::TasksApi::UserTasksCache)
          .to receive(:fetch)
          .and_return(cached_result)

        expect(subject).to eq(cached_result)
      end
    end

    describe "pagination params" do
      before { create_list(:task, 5, user: user) }

      context "with per_page param" do
        let(:params) do
          { query: {}, pagination: { per_page: 2 } }
        end

        it "limits results to per_page" do
          expect(subject[:tasks].size).to eq(2)
        end
      end

      context "with page and per_page params" do
        let(:params) do
          { query: {}, pagination: { page: 2, per_page: 2 } }
        end

        it "returns the correct page of results" do
          all_ids = user.tasks.order(created_at: :desc).pluck(:id)
          expect(subject[:tasks].map { |t| t[:id] }).to eq(all_ids[2..3])
        end

        it "includes correct pagination metadata" do
          expect(subject[:pagination]).to include(
            current_page: 2,
            per_page: 2,
            total_pages: 3,
            total_count: 5
          )
        end
      end
    end

    describe "query params" do
      before do
        create(:task, user: user, status: :pending)
        create(:task, user: user, status: :completed)
      end

      let(:params) do
        { query: { status: "pending" }, pagination: {} }
      end

      it "passes query params through to filter results" do
        statuses = subject[:tasks].map { |t| t[:status] }.uniq
        expect(statuses).to eq([ "pending" ])
      end
    end
  end
end
