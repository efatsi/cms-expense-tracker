class CreateCsvStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :csv_statements do |t|
      t.references :payment_method, null: false, foreign_key: true
      t.integer :imported_count
      t.integer :skipped_count

      t.timestamps
    end
  end
end
