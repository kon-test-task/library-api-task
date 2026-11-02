class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers do |t|
      t.string :card_number, limit: 6, null: false
      t.string :full_name, null: false
      t.string :email, null: false

      t.timestamps

      t.index :card_number, unique: true
      t.index :email, unique: true
      t.check_constraint "card_number ~ '^[0-9]{6}$'", name: "readers_card_number_six_digits"
    end
  end
end
