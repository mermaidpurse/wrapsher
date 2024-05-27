require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

module Wrapsher
  class Syntax < Parslet::Parser

    def spaced(c)
      str(c) >> match('\s')
    end

    rule(:program)                  { statement.repeat }
    rule(:statement)                { (use_version_statement | module_statement) >> eol }
    rule(:use_version_statement)    { str('use') >> space >> str('version') >> space >> version.as(:version) }
    rule(:module_statement)         { str('module') >> space >> word.as(:module) }
    rule(:version)                  { match('[0-9.]').repeat(1) }
    rule(:space)                    { match('\s').repeat(1) }
    rule(:word)                     { match('[a-zA-Z0-9_]').repeat }
    rule(:eol)                      { match('\n') | spaced(';') }

    root(:program)

  end
end
