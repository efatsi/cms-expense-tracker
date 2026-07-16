class CreateChargeReceipts < ActiveRecord::Migration[8.1]
  def up
    create_table :charge_receipts do |t|
      t.references :charge, null: false, foreign_key: true
      t.references :receipt, null: false, foreign_key: true

      t.timestamps
    end

    add_index :charge_receipts, [ :charge_id, :receipt_id ], unique: true

    # Migrate existing receipt_id data to join table
    execute <<~SQL
      INSERT INTO charge_receipts (charge_id, receipt_id, created_at, updated_at)
      SELECT id, receipt_id, NOW(), NOW()
      FROM charges
      WHERE receipt_id IS NOT NULL
    SQL

    remove_foreign_key :charges, :receipts
    remove_column :charges, :receipt_id
  end

  def down
    add_column :charges, :receipt_id, :bigint
    add_foreign_key :charges, :receipts

    execute <<~SQL
      UPDATE charges c
      SET receipt_id = cr.receipt_id
      FROM charge_receipts cr
      WHERE cr.charge_id = c.id
    SQL

    drop_table :charge_receipts
  end
end
