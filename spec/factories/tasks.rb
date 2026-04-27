FactoryBot.define do
  factory :task do
    user
    sequence(:title) { |n| "Task #{n}" }
    description { "This is a task description" }
    status { :pending }
    priority { :medium }
    due_date { 1.week.from_now }

    trait :pending do
      status { :pending }
    end

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :low_priority do
      priority { :low }
    end

    trait :medium_priority do
      priority { :medium }
    end

    trait :high_priority do
      priority { :high }
    end

    trait :urgent_priority do
      priority { :urgent }
    end
  end
end
