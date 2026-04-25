require "rails_helper"

RSpec.describe "Api::V1::Tasks", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/tasks" do
    before do
      # Create sample tasks
      create_list(:task, 5, user: user)
      create(:task, user: user, status: :completed)
    end

    it "returns all tasks for the user" do
      get "/api/v1/tasks", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["tasks"].length).to eq(6)
      expect(json["pagination"]["total_count"]).to eq(6)
    end

    it "filters by status" do
      get "/api/v1/tasks", params: { status: "completed" }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["tasks"].length).to eq(1)
    end

    it "returns unauthorized without token" do
      get "/api/v1/tasks"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/tasks" do
    let(:valid_params) do
      {
        title: "Complete project documentation",
        description: "Write comprehensive API docs",
        priority: "high",
        status: "pending",
        due_date: 1.week.from_now.iso8601
      }
    end

    it "creates a new task" do
      expect {
        post "/api/v1/tasks", params: valid_params, headers: headers
      }.to change(Task, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["task"]["title"]).to eq("Complete project documentation")
    end

    it "returns validation errors for invalid data" do
      post "/api/v1/tasks", params: { title: "" }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"][0]).to eq("Title can't be blank")
    end
  end

  describe "PUT /api/v1/tasks/:id" do
    let(:task) { create(:task, user: user) }

    it "updates the task" do
      put "/api/v1/tasks/#{task.id}",
          params: { title: "Updated title" },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(task.reload.title).to eq("Updated title")
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    let!(:task) { create(:task, user: user) }

    it "deletes the task" do
      expect {
        delete "/api/v1/tasks/#{task.id}", headers: headers
      }.to change(Task, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  private

  def json
    JSON.parse(response.body)
  end
end
