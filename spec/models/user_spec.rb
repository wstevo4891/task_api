require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:tasks).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:user) }

    describe 'email validation' do
      it { is_expected.to validate_presence_of(:email) }

      it 'validates uniqueness of email case-insensitively' do
        create(:user, email: 'test@example.com')
        user = build(:user, email: 'TEST@EXAMPLE.COM')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end

      it 'validates email format' do
        user = build(:user, email: 'invalid-email')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('is invalid')
      end

      it 'accepts valid email formats' do
        valid_emails = [
          'user@example.com',
          'user.name@example.com',
          'user+tag@example.co.uk'
        ]
        valid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).to be_valid, "expected #{email} to be valid"
        end
      end
    end

    describe 'name validation' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_length_of(:name).is_at_least(2).is_at_most(100) }
    end

    describe 'password validation' do
      it 'validates minimum password length for new records' do
        user = build(:user, password: 'short')
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('is too short (minimum is 8 characters)')
      end

      it 'requires a password for new records' do
        user = build(:user, password: nil, password_confirmation: nil)
        expect(user).not_to be_valid
      end

      it 'does not validate password if not updating password on existing record' do
        user = create(:user)
        user.name = 'Updated Name'
        expect(user).to be_valid
      end

      it 'validates password length when explicitly updating password' do
        user = create(:user)
        user.password = 'short'
        user.password_confirmation = 'short'
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('is too short (minimum is 8 characters)')
      end
    end
  end

  describe 'secure password' do
    let(:password) { 'securepassword123' }

    describe '#password_digest' do
      it 'creates a password digest when password is set' do
        user = build(:user, password: password, password_confirmation: password)
        expect(user.password_digest).to_not be_nil
      end

      it 'does not store the plain text password' do
        user = create(:user, password: password, password_confirmation: password)
        expect(user.password_digest).not_to eq(password)
      end
    end

    describe '#authenticate' do
      let(:user) { create(:user, password: password, password_confirmation: password) }

      it 'returns the user when password is correct' do
        expect(user.authenticate(password)).to eq(user)
      end

      it 'returns false when password is incorrect' do
        expect(user.authenticate('wrongpassword')).to be_falsy
      end

      it 'is case sensitive' do
        expect(user.authenticate('SECUREPASSWORD123')).to be_falsy
      end
    end

    describe 'password confirmation' do
      it 'requires password confirmation when setting password' do
        user = build(:user, password: password, password_confirmation: 'different')
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("doesn't match Password")
      end

      it 'is valid when password and confirmation match' do
        user = build(:user, password: password, password_confirmation: password)
        expect(user).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe '#downcase_email' do
      it 'downcases email before saving' do
        user = create(:user, email: 'TEST@EXAMPLE.COM')
        expect(user.email).to eq('test@example.com')
      end

      it 'persists the downcased email' do
        user = create(:user, email: 'UPPERCASE@EXAMPLE.COM')
        user.reload
        expect(user.email).to eq('uppercase@example.com')
      end
    end
  end

  describe 'associations behavior' do
    let(:user) { create(:user) }
    let(:task_1) { create(:task, user: user) }
    let(:task_2) { create(:task, user: user) }

    it 'returns all tasks for a user' do
      task_1
      task_2
      expect(user.tasks.count).to eq(2)
    end

    it 'destroys dependent tasks when user is destroyed' do
      task_1
      task_2
      user_id = user.id

      expect { user.destroy }
        .to change { Task.where(user_id: user_id).count }
        .from(2).to(0)
    end
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'creates a user with default attributes' do
      user = build(:user)
      expect(user.email).to be_present
      expect(user.name).to be_present
      expect(user.password).to be_present
    end
  end
end
