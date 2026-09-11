# Payment Methods
camp_amex = PaymentMethod.find_or_create_by!(name: "Camp AmEx") do |pm|
  pm.account_last_four = "1234"
end

elias_amex = PaymentMethod.find_or_create_by!(name: "Elias AmEx") do |pm|
  pm.account_last_four = "5678"
end

# Expense Categories
Expense.delete_all
ExpenseCategory.delete_all
{
  nil            => [ "Uncategorized" ],
  "Store"        => [ "Merch + Uniforms", "Photos", "Rx" ],
  "Admin"        => [ "Payroll", "Staff Training", "Pro Fees (financial, legal, comp...)",
                      "Laundry", "Contributions / Donations", "Employee Benefits",
                      "CMS Liability Insurance", "Marketing - Parents Weekend", "Marketing",
                      "Office Expenses", "Payroll Taxes", "Transportation", "Utilities" ],
  "Facilities"   => [ "Payroll", "Cleaning Supplies", "Building Maintenance / Repairs",
                      "Grounds + Landscaping", "Plumbing + Septic" ],
  "Food Service" => [ "Salaries", "Kitchen Supplies", "Staff Training", "Food",
                      "Staff Broker Fees", "Wolfoods" ],
  "Healthcare"   => [ "Payroll", "Supplies" ],
  "Program"      => [ "PD Salary", "Counselor Salaries", "Supplies",
                      "Counselor Training + Certs" ],
  "Personal"     => [ "Ann's Personal" ],
  "Barn"         => [ "Building / Grounds", "Horsecare" ]
}.each do |section, names|
  names.each do |name|
    ExpenseCategory.create!(name: name, section: section, active: true)
  end
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
