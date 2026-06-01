# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::TasksApi::UserTasksSerializer do
  let(:pagination_data) { { current_page: 1, per_page: 20, total_pages: 1, total_count: 2 } }
  let(:paginator) { instance_double(Paginator, pagination_json: pagination_data) }
  let(:tasks) { [ double(id: 1), double(id: 2) ] }
  let(:data) { { total: 2, tasks: tasks } }
  let(:serializer) { ->(task) { { id: task.id, serialized: true } } }

  subject(:result) { described_class.new(paginator, data, serializer).as_json }

  describe "#as_json" do
    it "returns a hash with :tasks and :pagination keys" do
      expect(result).to include(:tasks, :pagination)
    end

    it "maps each task through the serializer" do
      expect(result[:tasks]).to eq([ { id: 1, serialized: true }, { id: 2, serialized: true } ])
    end

    it "delegates pagination to paginator.pagination_json with total" do
      expect(paginator).to receive(:pagination_json).with(2).and_return(pagination_data)
      described_class.new(paginator, data, serializer).as_json
    end

    it "includes the pagination data returned by paginator" do
      expect(result[:pagination]).to eq(pagination_data)
    end

    context "with an empty task list" do
      let(:data) { { total: 0, tasks: [] } }

      it "returns an empty tasks array" do
        expect(result[:tasks]).to eq([])
      end

      it "passes 0 as total to pagination_json" do
        expect(paginator).to receive(:pagination_json).with(0).and_return({})
        described_class.new(paginator, data, serializer).as_json
      end
    end

    context "with the default TaskSerializer" do
      let(:task) { create(:task) }
      let(:data) { { total: 1, tasks: [ task ] } }

      subject(:result) { described_class.new(paginator, data).as_json }

      it "serializes tasks using TaskSerializer" do
        expect(result[:tasks].first).to include(:id, :title, :status, :priority)
      end

      it "calls TaskSerializer for each task" do
        expect(TaskSerializer).to receive(:call).with(task).and_call_original
        described_class.new(paginator, data).as_json
      end
    end
  end
end
