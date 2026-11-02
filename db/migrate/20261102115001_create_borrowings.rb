class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :book, null: false, foreign_key: true, index: false
      t.references :reader, null: false, foreign_key: true
      t.datetime :borrowed_at, null: false
      t.date :due_date, null: false
      t.datetime :returned_at

      t.timestamps

      t.index :book_id, unique: true, where: "returned_at IS NULL", name: "index_borrowings_on_book_id_active"
      t.index [ :book_id, :borrowed_at ], order: { borrowed_at: :desc }
      t.index :due_date, where: "returned_at IS NULL", name: "index_borrowings_on_due_date_active"
      t.check_constraint "returned_at IS NULL OR returned_at >= borrowed_at", name: "borrowings_returned_at_after_borrowed_at"
    end
  end
end
