require 'logger'
require 'parslet'

module Wrapsher
  class Transform < Parslet::Transform

    rule(subtree(:program)) { program }

  end
end
