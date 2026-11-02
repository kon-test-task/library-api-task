class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :serial_number, limit: 6, null: false
      t.string :title, null: false
      t.integer :status, null: false, default: 0

      t.timestamps

      t.index :serial_number, unique: true
      t.check_constraint "serial_number ~ '^[0-9]{6}$'", name: "books_serial_number_six_digits"
    end
  end
end
