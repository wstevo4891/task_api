# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "Seeding database..."

puts "Clearing tasks..."

Task.delete_all

puts "Creating 10 sample users with tasks..."

(1..10).each do |num|
  current_user = User.find_or_create_by(id: num) do |user|
    user.email = Faker::Internet.email
    user.name = Faker::Name.name
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  (1..10).each do |num|
    Task.create(
      user: current_user,
      title: "Task #{num}",
      description: Faker::Lorem.paragraph(sentence_count: 2),
      status: Task.statuses.keys.sample,
      priority: Task.priorities.keys.sample,
      due_date: Faker::Date.forward(from: 1.day.from_now, days: 60)
    )
  end
end

puts "Sample users and tasks are in place."

puts "Finished seeding."
