require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
  end

  describe 'enums' do
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

  describe 'validations' do
    let(:user) { create(:user) }
    let(:valid_attributes) do
      {
        user: user,
        title: 'Valid Task Title',
        description: 'A valid description',
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

    describe 'title validation' do
      context 'when title is too short' do
        it 'is invalid' do
          task = Task.new(valid_attributes.merge(title: 'ab'))
          expect(task).not_to be_valid
          expect(task.errors[:title]).to include('is too short (minimum is 3 characters)')
        end
      end

      context 'when title is too long' do
        it 'is invalid' do
          task = Task.new(valid_attributes.merge(title: 'a' * 201))
          expect(task).not_to be_valid
          expect(task.errors[:title]).to include('is too long (maximum is 200 characters)')
        end
      end

      context 'when title is blank' do
        it 'is invalid' do
          task = Task.new(valid_attributes.merge(title: ''))
          expect(task).not_to be_valid
          expect(task.errors[:title]).to include("can't be blank")
        end
      end
    end

    describe 'description validation' do
      context 'when description is too long' do
        it 'is invalid' do
          task = Task.new(valid_attributes.merge(description: 'a' * 5001))
          expect(task).not_to be_valid
          expect(task.errors[:description]).to include('is too long (maximum is 5000 characters)')
        end
      end

      context 'when description is blank' do
        it 'is valid' do
          task = Task.new(valid_attributes.merge(description: ''))
          expect(task).to be_valid
        end
      end

      context 'when description is nil' do
        it 'is valid' do
          task = Task.new(valid_attributes.merge(description: nil))
          expect(task).to be_valid
        end
      end
    end

    describe 'status validation' do
      context 'when status is blank' do
        it 'is invalid' do
          task = Task.new(valid_attributes.merge(status: nil))
          expect(task).not_to be_valid
          expect(task.errors[:status]).to include("can't be blank")
        end
      end
    end

    describe 'priority validation' do
      context 'when priority is blank' do
        it 'is invalid' do
          task = Task.new(valid_attributes.merge(priority: nil))
          expect(task).not_to be_valid
          expect(task.errors[:priority]).to include("can't be blank")
        end
      end
    end
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:pending_task) { create(:task, user: user, status: :pending, due_date: 5.days.from_now) }
    let!(:in_progress_task) { create(:task, user: user, status: :in_progress, due_date: 2.days.from_now) }
    let!(:completed_task) { create(:task, user: user, status: :completed, due_date: 1.day.ago) }
    let!(:cancelled_task) { create(:task, user: user, status: :cancelled, due_date: 3.days.from_now) }

    describe '.active' do
      it 'returns all tasks that are not completed or cancelled' do
        result = Task.active
        expect(result).to include(pending_task, in_progress_task)
        expect(result).not_to include(completed_task, cancelled_task)
      end

      it 'returns 2 active tasks' do
        expect(Task.active.count).to eq(2)
      end
    end

    describe '.overdue' do
      let!(:overdue_task) { create(:task, user: user, status: :pending, due_date: 1.day.ago) }
      let!(:due_soon_task) { create(:task, user: user, status: :in_progress, due_date: 1.day.from_now) }

      it 'returns active tasks with due dates in the past' do
        result = Task.overdue
        expect(result).to include(overdue_task)
        expect(result).not_to include(pending_task, in_progress_task, due_soon_task, completed_task, cancelled_task)
      end

      it 'does not return completed or cancelled tasks' do
        expect(Task.overdue).not_to include(completed_task, cancelled_task)
      end
    end

    describe '.due_soon' do
      let!(:due_in_1_day) { create(:task, user: user, status: :pending, due_date: 1.day.from_now) }
      let!(:due_in_2_days) { create(:task, user: user, status: :in_progress, due_date: 2.days.from_now) }
      let!(:due_in_4_days) { create(:task, user: user, status: :pending, due_date: 4.days.from_now) }

      it 'returns active tasks due within 3 days' do
        result = Task.due_soon
        expect(result).to include(due_in_1_day, due_in_2_days)
        expect(result).not_to include(due_in_4_days)
      end

      it 'does not return completed or cancelled tasks' do
        expect(Task.due_soon).not_to include(completed_task, cancelled_task)
      end
    end

    describe '.by_priority' do
      before { DatabaseCleaner.clean }
      let!(:low_priority) { create(:task, user: user, priority: :low) }
      let!(:medium_priority) { create(:task, user: user, priority: :medium) }
      let!(:high_priority) { create(:task, user: user, priority: :high) }
      let!(:urgent_priority) { create(:task, user: user, priority: :urgent) }

      it 'returns tasks ordered by priority in descending order' do
        result = Task.by_priority
        priorities = result.pluck(:priority)
        expect(priorities).to eq([ 'urgent', 'high', 'medium', 'low' ])
      end
    end
  end

  describe 'factory' do
    it 'creates a valid task' do
      task = build(:task)
      expect(task).to be_valid
    end

    it 'persists the task to the database' do
      expect {
        create(:task)
      }.to change(Task, :count).by(1)
    end
  end
end
