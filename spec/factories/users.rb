FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { 'Test User' }
    password { 'password123' }
    password_confirmation { 'password123' }
  end
end

# spec/factories/tasks.rb
FactoryBot.define do
  factory :task do
    sequence(:title) { |n| "Task #{n}" }
    description { 'A sample task description' }
    status { :pending }
    priority { :medium }
    due_date { 1.week.from_now }
    association :user
  end
end
