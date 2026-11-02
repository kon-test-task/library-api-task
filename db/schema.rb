# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_02_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "authors", force: :cascade do |t|
    t.citext "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_authors_on_name", unique: true
  end

  create_table "book_authors", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.bigint "author_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_book_authors_on_author_id"
    t.index ["book_id", "author_id"], name: "index_book_authors_on_book_id_and_author_id", unique: true
    t.index ["book_id", "position"], name: "index_book_authors_on_book_id_and_position", unique: true
  end

  create_table "books", force: :cascade do |t|
    t.string "serial_number", limit: 6, null: false
    t.string "title", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["serial_number"], name: "index_books_on_serial_number", unique: true
    t.check_constraint "serial_number::text ~ '^[0-9]{6}$'::text", name: "books_serial_number_six_digits"
  end

  create_table "borrowings", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.bigint "reader_id", null: false
    t.datetime "borrowed_at", null: false
    t.date "due_date", null: false
    t.datetime "returned_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "upcoming_reminder_sent_at"
    t.datetime "due_reminder_sent_at"
    t.index ["book_id", "borrowed_at"], name: "index_borrowings_on_book_id_and_borrowed_at", order: { borrowed_at: :desc }
    t.index ["book_id"], name: "index_borrowings_on_book_id_active", unique: true, where: "(returned_at IS NULL)"
    t.index ["due_date"], name: "index_borrowings_on_due_date_active", where: "(returned_at IS NULL)"
    t.index ["reader_id"], name: "index_borrowings_on_reader_id"
    t.check_constraint "returned_at IS NULL OR returned_at >= borrowed_at", name: "borrowings_returned_at_after_borrowed_at"
  end

  create_table "readers", force: :cascade do |t|
    t.string "card_number", limit: 6, null: false
    t.string "full_name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_number"], name: "index_readers_on_card_number", unique: true
    t.index ["email"], name: "index_readers_on_email", unique: true
    t.check_constraint "card_number::text ~ '^[0-9]{6}$'::text", name: "readers_card_number_six_digits"
  end

  add_foreign_key "book_authors", "authors"
  add_foreign_key "book_authors", "books"
  add_foreign_key "borrowings", "books"
  add_foreign_key "borrowings", "readers"
end
