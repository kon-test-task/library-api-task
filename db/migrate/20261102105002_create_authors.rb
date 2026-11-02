class CreateAuthors < ActiveRecord::Migration[8.1]
  def change
    enable_extension "citext"

    create_table :authors do |t|
      t.citext :name, null: false

      t.timestamps

      t.index :name, unique: true
    end
  end
end
