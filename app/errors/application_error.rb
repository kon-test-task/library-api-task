# Base for failures the API reports to clients. The class name becomes the error code,
# so Books::AlreadyBorrowed reports "already_borrowed". ApplicationController picks the status.
class ApplicationError < StandardError
  def code = self.class.name.demodulize.underscore
  def field = nil
end
