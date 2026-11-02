# Demo data. Safe to run twice: a record that already exists stays as it is.
# The serial and card numbers match the examples in swagger/v1/swagger.yaml.
# Serials 004219 and 004220 stay free for the "Add a book" examples.

seed_reader = lambda do |card_number, full_name, email|
  Reader.find_or_create_by!(card_number: card_number) do |reader|
    reader.full_name = full_name
    reader.email = email
  end
end

seed_book = lambda do |serial_number, title, authors|
  Book.find_or_create_by!(serial_number: serial_number) do |book|
    book.title = title
    book.author_names = authors
  end
end

# Skips a book that already has loans, so a second run adds no history.
seed_loan = lambda do |book, reader, **attributes|
  next if book.borrowings.exists?

  book.borrowings.create!(reader: reader, **attributes)
  book.borrowed! unless attributes[:returned_at]
end

jan = seed_reader.call("100001", "Jan Kowalski", "jan.kowalski@example.com")
anna = seed_reader.call("100002", "Anna Nowak", "anna.nowak@example.com")
piotr = seed_reader.call("100003", "Piotr Wiśniewski", "piotr.wisniewski@example.com")

# Available, with one returned loan in its history.
oryx = seed_book.call("000101", "Oryx and Crake", [ "Margaret Atwood" ])
seed_loan.call(oryx, anna, borrowed_at: 60.days.ago, returned_at: 40.days.ago)

# Two authors, on loan, with no reminder due yet.
omens = seed_book.call("000102", "Good Omens", [ "Terry Pratchett", "Neil Gaiman" ])
seed_loan.call(omens, jan, borrowed_at: 10.days.ago)

# Available and never lent. The docs use it for the delete example.
seed_book.call("000103", "The Left Hand of Darkness", [ "Ursula K. Le Guin" ])

# Due in 3 days. The reminder job sends the upcoming mail.
dune = seed_book.call("000104", "Dune", [ "Frank Herbert" ])
seed_loan.call(dune, anna, borrowed_at: 27.days.ago)

# Due today. The reminder job sends the due-day mail.
solaris = seed_book.call("000105", "Solaris", [ "Stanisław Lem" ])
seed_loan.call(solaris, piotr, borrowed_at: 30.days.ago)

# Overdue by 5 days. Both reminders already went out, so the job sends nothing.
emma = seed_book.call("000106", "Emma", [ "Jane Austen" ])
seed_loan.call(emma, jan, borrowed_at: 35.days.ago, upcoming_reminder_sent_at: 8.days.ago, due_reminder_sent_at: 5.days.ago)
