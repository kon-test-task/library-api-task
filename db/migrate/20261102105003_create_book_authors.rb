class CreateBookAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :book_authors do |t|
      t.references :book, null: false, foreign_key: true, index: false
      t.references :author, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps

      t.index [ :book_id, :author_id ], unique: true
      t.index [ :book_id, :position ], unique: true
    end
  end
end
