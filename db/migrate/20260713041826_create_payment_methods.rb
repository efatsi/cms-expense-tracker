class CreatePaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_methods do |t|
      t.string :name
      t.string :account_last_four

      t.timestamps
    end
  end
end
