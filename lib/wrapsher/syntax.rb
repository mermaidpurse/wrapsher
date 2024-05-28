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
    rule(:statement)                { (use_statement | meta_statement | module_statement | type_statement | fun_definition) >> eol }
    rule(:use_statement)            { use_version_statement }
    rule(:meta_statement)           { str('meta') >> space >> word.as(:meta_field) >> space >> string.as(:meta_data) }
    rule(:use_version_statement)    { str('use') >> space >> str('version') >> space >> version.as(:version) }
    rule(:module_statement)         { str('module') >> space >> word.as(:module) }
    rule(:type_statement)           { str('type') >> space >> word.as(:type) }

    rule(:fun_definition)           { (signature.as(:signature) >> block.as(:body)).as(:fun_definition) }
    rule(:signature)                { word.as(:type) >> space >> word.as(:name) >> lparen >> arg_definitions.as(:arg_definitions) >> rparen }
    rule(:arg_definitions)          { (arg_definition >> (comma >> arg_definition).repeat).maybe }
    rule(:arg_definition)           { word.as(:type) >> space >> word.as(:name) }

    rule(:block)                    { str('{ a + b }') }

    rule(:version)                  { match('[0-9.]').repeat(1) }
    rule(:string)                   { single_quoted }
    rule(:single_quoted)            { str('\'') >> char.repeat.as(:single_quoted) >> str('\'') }

    rule(:lbrace)                   { str('{') >> space? }
    rule(:rbrace)                   { str('}') >> space? }
    rule(:lparen)                   { str('(') >> space? }
    rule(:rparen)                   { str(')') >> space? }
    rule(:comma)                    { str(',') >> space? }
    rule(:char)                     { str('\\\'') | (str('\'').absent? >> any) }
    rule(:space)                    { match('\s').repeat(1) }
    rule(:space?)                   { space.maybe }
    rule(:word)                     { match('[a-zA-Z0-9_]').repeat(1) }
    rule(:eol)                      { (match('\n') | str(';')) >> space? }

    root(:program)

  end
end
