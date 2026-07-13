# Payment Methods
camp_amex = PaymentMethod.find_or_create_by!(name: "Camp AmEx") do |pm|
  pm.account_last_four = "1234"
end

elias_amex = PaymentMethod.find_or_create_by!(name: "Elias AmEx") do |pm|
  pm.account_last_four = "5678"
end

# Expense Categories
%w[Supplies Food Travel Equipment Utilities Other].each do |name|
  ExpenseCategory.find_or_create_by!(name: name)
end

# Admin users
[
  { email: "elias@campmontshenandoah.com", name: "Elias" },
  { email: "ann@campmontshenandoah.com", name: "Ann" }
].each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.name = attrs[:name]
  user.role = :admin
  user.password = "100yearsstrong"
  user.save!
  puts "  Admin: #{user.email}"
end

# Employee users
[
  { email: "kelsey@campmontshenandoah.com", name: "Kelsey" }
].each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.name = attrs[:name]
  user.role = :employee
  user.password = "100yearsstrong"
  user.save!
  puts "  Employee: #{user.email}"
end

# Remove placeholder admin if it exists
User.find_by(email: "admin@example.com")&.destroy

puts "Seeded:"
puts "  Payment methods: #{PaymentMethod.count}"
puts "  Expense categories: #{ExpenseCategory.count}"
puts "  Users: #{User.count}"
