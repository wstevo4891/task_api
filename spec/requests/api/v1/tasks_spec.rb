require "rails_helper"

RSpec.describe "Api::V1::Tasks", type: :request do
  let(:user) { create(:user) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/tasks" do
    before do
      # Create sample tasks
      create_list(:task, 5, user: user)
      create(:task, user: user, status: :completed)
    end

    context "without filters" do
      before do
        get "/api/v1/tasks", headers: headers
      end

      it "responds with http status: ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all tasks for the user" do
        expect(json["tasks"].length).to eq(6)
      end

      it "responds with the expected pagination count" do
        expect(json["pagination"]["total_count"]).to eq(6)
      end
    end

    context "when filtered by status: completed" do
      before do
        get "/api/v1/tasks", params: { status: "completed" }, headers: headers
      end

      it "responds with http status: ok" do
        expect(response).to have_http_status(:ok)
      end

      it "returns one task" do
        expect(json["tasks"].length).to eq(1)
      end
    end

    context "without authorization token" do
      it "responds with http status: unauthorized" do
        get "/api/v1/tasks"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/tasks" do
    context "with valid params" do
      let(:valid_params) do
        {
          title: "Complete project documentation",
          description: "Write comprehensive API docs",
          priority: "high",
          status: "pending",
          due_date: 1.week.from_now.iso8601
        }
      end
      let(:valid_request) {
        post "/api/v1/tasks", params: valid_params, headers: headers
      }

      it "creates a new task" do
        expect { valid_request }.to change { Task.count }.by(1)
      end

      describe "the response" do
        before { valid_request }

        it "has http status: created" do
          expect(response).to have_http_status(:created)
        end

        it "has a task with the expected title" do
          expect(json["task"]["title"]).to eq("Complete project documentation")
        end
      end
    end

    context "with invalid params" do
      let(:invalid_request) {
        post "/api/v1/tasks", params: { title: "" }, headers: headers
      }

      it "does not create a new task" do
        expect { invalid_request }.not_to change { Task.count }
      end

      describe "the response" do
        before { invalid_request }

        it "has http status: unprocessable content" do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "has an error message about the missing title" do
          expect(json["error"][0]).to eq("Title can't be blank")
        end
      end
    end
  end

  describe "PUT /api/v1/tasks/:id" do
    let(:task) { create(:task, user: user) }

    before do
      put "/api/v1/tasks/#{task.id}",
          params: { title: "Updated title" },
          headers: headers
    end

    it "responds with http status: ok" do
      expect(response).to have_http_status(:ok)
    end

    it "updates the task" do
      expect(task.reload.title).to eq("Updated title")
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    let!(:task) { create(:task, user: user) }

    let(:delete_request) do
      delete "/api/v1/tasks/#{task.id}", headers: headers
    end

    it "deletes the task" do
      expect { delete_request }.to change { Task.count }.by(-1)
    end

    it "responds with http status: no content" do
      delete_request
      expect(response).to have_http_status(:no_content)
    end
  end
end
