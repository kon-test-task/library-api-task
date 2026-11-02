# The request is valid but the current state refuses it. The client can retry once the state changes.
class ConflictError < ApplicationError; end
