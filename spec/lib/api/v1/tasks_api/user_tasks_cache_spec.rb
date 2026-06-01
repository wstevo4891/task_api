# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::TasksApi::UserTasksCache do
  let(:paginator) { instance_double(Paginator, per_page: 20, page: 1) }
  let(:user_id) { 42 }

  subject(:cache) { described_class.new(user_id, params, paginator) }

  describe "#key" do
    context "with no optional params" do
      let(:params) { {} }

      it "generates a key scoped to user_id with pagination suffix" do
        expect(cache.key).to eq("user-tasks/42/per_page=20/page=1")
      end
    end

    context "with status param" do
      let(:params) { { status: "pending" } }

      it "includes status in the key" do
        expect(cache.key).to eq("user-tasks/42/pending/per_page=20/page=1")
      end
    end

    context "with blank status param" do
      let(:params) { { status: "" } }

      it "omits blank status from the key" do
        expect(cache.key).to eq("user-tasks/42/per_page=20/page=1")
      end
    end

    context "with priority param" do
      let(:params) { { priority: "high" } }

      it "includes priority in the key" do
        expect(cache.key).to eq("user-tasks/42/high/per_page=20/page=1")
      end
    end

    context "with overdue: 'true'" do
      let(:params) { { overdue: "true" } }

      it "includes 'overdue' in the key" do
        expect(cache.key).to include("overdue/")
      end
    end

    context "with overdue: 'false'" do
      let(:params) { { overdue: "false" } }

      it "omits 'overdue' from the key" do
        expect(cache.key).not_to include("overdue/")
      end
    end

    context "with overdue as a boolean true" do
      let(:params) { { overdue: true } }

      it "omits 'overdue' from the key (only the string 'true' matches)" do
        expect(cache.key).not_to include("overdue/")
      end
    end

    context "with due_soon: 'true'" do
      let(:params) { { due_soon: "true" } }

      it "includes 'due_soon' in the key" do
        expect(cache.key).to include("due_soon/")
      end
    end

    context "with due_soon: 'false'" do
      let(:params) { { due_soon: "false" } }

      it "omits 'due_soon' from the key" do
        expect(cache.key).not_to include("due_soon/")
      end
    end

    context "with due_soon as a boolean true" do
      let(:params) { { due_soon: true } }

      it "omits 'due_soon' from the key (only the string 'true' matches)" do
        expect(cache.key).not_to include("due_soon/")
      end
    end

    context "with sort param" do
      let(:params) { { sort: "due_date" } }

      it "includes sort in the key" do
        expect(cache.key).to include("due_date/")
      end
    end

    context "with all optional params" do
      let(:params) do
        {
          status: "pending",
          priority: "high",
          overdue: "true",
          due_soon: "true",
          sort: "due_date"
        }
      end

      it "combines all params in the correct order" do
        expect(cache.key).to eq(
          "user-tasks/42/pending/high/overdue/due_soon/due_date/per_page=20/page=1"
        )
      end
    end

    context "with different paginator values" do
      let(:paginator) { instance_double(Paginator, per_page: 10, page: 3) }
      let(:params) { {} }

      it "reflects paginator per_page and page in the key" do
        expect(cache.key).to eq("user-tasks/42/per_page=10/page=3")
      end
    end

    context "with a different user_id" do
      let(:user_id) { 99 }
      let(:params) { {} }

      it "scopes the key to the correct user" do
        expect(cache.key).to start_with("user-tasks/99/")
      end
    end
  end

  describe "#fetch" do
    let(:params) { {} }

    it "delegates to Rails.cache.fetch with the cache key and 1 hour expiry" do
      expect(Rails.cache).to receive(:fetch).with(cache.key, expires_in: 1.hour).and_return("cached")
      cache.fetch { "data" }
    end

    it "calls the block on cache miss and returns its value" do
      allow(Rails.cache).to receive(:fetch).with(cache.key, expires_in: 1.hour).and_yield
      expect(cache.fetch { "fresh data" }).to eq("fresh data")
    end

    it "logs a cache miss message on cache miss" do
      allow(Rails.cache).to receive(:fetch).with(cache.key, expires_in: 1.hour).and_yield
      expect(Rails.logger).to receive(:info).with("--- Cache Miss! Fetching data for user tasks ---")
      cache.fetch { "data" }
    end

    it "returns cached data without calling the block on cache hit" do
      cached_value = { tasks: [], pagination: {} }
      allow(Rails.cache).to receive(:fetch).with(cache.key, expires_in: 1.hour).and_return(cached_value)

      block_called = false
      result = cache.fetch { block_called = true }

      expect(block_called).to be(false)
      expect(result).to eq(cached_value)
    end
  end
end
