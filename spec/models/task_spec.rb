require "rails_helper"

RSpec.describe Task, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "enums" do
    it do
      is_expected
        .to define_enum_for(:status)
        .with_values(pending: 0, in_progress: 1, completed: 2, cancelled: 3)
    end

    it do
      is_expected
        .to define_enum_for(:priority)
        .with_values(low: 0, medium: 1, high: 2, urgent: 3)
    end
  end

  describe "validations" do
    let(:user) { create(:user) }
    let(:valid_attributes) do
      {
        user: user,
        title: "Valid Task Title",
        description: "A valid description",
        status: :pending,
        priority: :medium
      }
    end

    subject { Task.new(valid_attributes) }

    it { is_expected.to validate_presence_of(:title) }

    it { is_expected.to validate_length_of(:title).is_at_least(3).is_at_most(200) }

    it { is_expected.to validate_length_of(:description).is_at_most(5000) }

    it { is_expected.to validate_presence_of(:status) }

    it { is_expected.to validate_presence_of(:priority) }

    describe "title validation" do
      context "when title is too short" do
        subject { Task.new(valid_attributes.merge(title: "ab")) }

        it { is_expected.not_to be_valid }

        it "should return expected error message" do
          message = "is too short (minimum is 3 characters)"
          subject.validate
          expect(subject.errors[:title]).to include(message)
        end
      end

      context "when title is too long" do
        subject { Task.new(valid_attributes.merge(title: "a" * 201)) }

        it { is_expected.not_to be_valid }

        it "should return expected error message" do
          message = "is too long (maximum is 200 characters)"
          subject.validate
          expect(subject.errors[:title]).to include(message)
        end
      end

      context "when title is blank" do
        subject { Task.new(valid_attributes.merge(title: "")) }

        it { is_expected.not_to be_valid }

        it "should return expected error message" do
          subject.validate
          expect(subject.errors[:title]).to include("can't be blank")
        end
      end
    end

    describe "description validation" do
      context "when description is too long" do
        subject { Task.new(valid_attributes.merge(description: "a" * 5001)) }

        it { is_expected.not_to be_valid }

        it "should return expected error message" do
          message = "is too long (maximum is 5000 characters)"
          subject.validate
          expect(subject.errors[:description]).to include(message)
        end
      end

      context "when description is blank" do
        it "is valid" do
          task = Task.new(valid_attributes.merge(description: ""))
          expect(task).to be_valid
        end
      end

      context "when description is nil" do
        it "is valid" do
          task = Task.new(valid_attributes.merge(description: nil))
          expect(task).to be_valid
        end
      end
    end

    describe "status validation" do
      context "when status is blank" do
        subject { Task.new(valid_attributes.merge(status: nil)) }

        it { is_expected.not_to be_valid }

        it "should return expected error message" do
          subject.validate
          expect(subject.errors[:status]).to include("can't be blank")
        end
      end
    end

    describe "priority validation" do
      context "when priority is blank" do
        subject { Task.new(valid_attributes.merge(priority: nil)) }

        it { is_expected.not_to be_valid }

        it "should return expected error message" do
          subject.validate
          expect(subject.errors[:priority]).to include("can't be blank")
        end
      end
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }

    let!(:pending_task) do
      create(:task, user: user, status: :pending, due_date: 5.days.from_now)
    end

    let!(:in_progress_task) do
      create(:task, user: user, status: :in_progress, due_date: 2.days.from_now)
    end

    let!(:completed_task) do
      create(:task, user: user, status: :completed, due_date: 1.day.ago)
    end

    let!(:cancelled_task) do
      create(:task, user: user, status: :cancelled, due_date: 3.days.from_now)
    end

    describe ".active" do
      subject { Task.active }

      it { is_expected.to include(pending_task, in_progress_task) }

      it { is_expected.not_to include(completed_task, cancelled_task) }
    end

    describe ".overdue" do
      let!(:overdue_task) do
        create(:task, user: user, status: :pending, due_date: 1.day.ago)
      end

      let!(:due_soon_task) do
        create(:task, user: user, status: :in_progress, due_date: 1.day.from_now)
      end

      subject { Task.overdue }

      it { is_expected.to include(overdue_task) }

      it { is_expected.not_to include(pending_task, in_progress_task, due_soon_task) }

      it { is_expected.not_to include(completed_task, cancelled_task) }
    end

    describe ".due_soon" do
      let!(:due_in_1_day) do
        create(:task, user: user, status: :pending, due_date: 1.day.from_now)
      end

      let!(:due_in_2_days) do
        create(:task, user: user, status: :in_progress, due_date: 2.days.from_now)
      end

      let!(:due_in_4_days) do
        create(:task, user: user, status: :pending, due_date: 4.days.from_now)
      end

      subject { Task.due_soon }

      it { is_expected.to include(due_in_1_day, due_in_2_days) }

      it { is_expected.not_to include(due_in_4_days) }

      it { is_expected.not_to include(completed_task, cancelled_task) }
    end

    describe ".by_priority" do
      before { DatabaseCleaner.clean }

      let!(:low_priority) { create(:task, user: user, priority: :low) }
      let!(:medium_priority) { create(:task, user: user, priority: :medium) }
      let!(:high_priority) { create(:task, user: user, priority: :high) }
      let!(:urgent_priority) { create(:task, user: user, priority: :urgent) }

      it "returns tasks ordered by priority in descending order" do
        result = Task.by_priority
        priorities = result.pluck(:priority)
        expect(priorities).to eq([ "urgent", "high", "medium", "low" ])
      end
    end
  end

  describe "factory" do
    it "creates a valid task" do
      task = build(:task)
      expect(task).to be_valid
    end

    it "persists the task to the database" do
      expect { create(:task) }.to change { Task.count }.by(1)
    end
  end
end
