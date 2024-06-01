require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

module Wrapsher
  class Syntax < Parslet::Parser

    rule(:program)                  { statement.repeat }
    rule(:statement)                { (use_statement | meta_statement | module_statement | type_statement | fun_definition) >> eol }
    rule(:use_statement)            { use_version_statement | use_module_statement | use_feature_statement | use_external_statement }
    rule(:meta_statement)           { str('meta') >> space >> word.as(:meta_field) >> space >> string.as(:meta_data) }
    rule(:use_version_statement)    { str('use') >> space >> str('version') >> space >> version.as(:version) }
    rule(:use_module_statement)     { str('use') >> space >> str('module') >> space >> word.as(:module) }
    rule(:use_external_statement)   { str('use') >> space >> str('external') >> space >> word.as(:external_command) }
    rule(:use_feature_statement)    { str('use') >> space >> str('feature') >> space >> word.as(:feature) }
    rule(:module_statement)         { str('module') >> space >> word.as(:module) }
    rule(:type_statement)           { str('type') >> space >> word.as(:type) }

    rule(:fun_definition)           { (signature.as(:signature) >> block.as(:body)).as(:fun_definition) }
    rule(:signature)                { word.as(:type) >> space >> word.as(:name) >> lparen >> arg_definitions.as(:arg_definitions) >> rparen }
    rule(:arg_definitions)          { (arg_definition >> (comma >> arg_definition).repeat).maybe }
    rule(:arg_definition)           { word.as(:type) >> space >> word.as(:name) }

    rule(:block)                    { lbrace >> whitespace? >> expressions >> whitespace? >> rbrace }
    rule(:expressions)              { expression >> (eol >> expression).repeat }
    rule(:expression)               { fun_call | secondary_op | primary_op | term }

    rule(:fun_call)                 { (qualified_word.as(:name) >> lparen >> space? >> fun_args.maybe >> space? >> rparen).as(:fun_call) }
    rule(:fun_args)                 { expression >> (comma >> expression).repeat }

    rule(:primary_op)               { (term.as(:left) >> space? >> primary_operator.as(:operator) >> space? >> expression.as(:right)).as(:primary_op) }
    rule(:secondary_op)             { (term.as(:left) >> space? >> secondary_operator.as(:operator) >> space? >> expression.as(:right)).as(:secondary_op) }

    rule(:primary_operator)         { str('+') | str('-') }
    rule(:secondary_operator)       { str('*') | str('/') | str('%') }
    rule(:term)                     { lparen >> expression.as(:group) >> rparen | lit_int | var_ref | string_term }
    rule(:lit_int)                  { match('[0-9]').repeat(1).as(:lit_int) >> space? }
    rule(:var_ref)                  { word.as(:var_ref) >> space? }
    rule(:string_term)              { string.as(:string_term) >> space? }

    rule(:version)                  { match('[0-9.]').repeat(1) }
    rule(:string)                   { single_quoted }
    rule(:single_quoted)            { str('\'') >> char.repeat.as(:single_quoted) >> str('\'') }

    rule(:lbrace)                   { str('{') }
    rule(:rbrace)                   { str('}') }
    rule(:lparen)                   { str('(') >> whitespace? }
    rule(:rparen)                   { str(')') >> whitespace? }
    rule(:comma)                    { str(',') >> whitespace? }
    rule(:char)                     { str('\\\'') | (str('\'').absent? >> any) }
    rule(:space)                    { match(' ').repeat(1) }
    rule(:space?)                   { space.maybe }
    rule(:whitespace)               { match('\s').repeat(1) }
    rule(:whitespace?)              { whitespace.maybe }
    rule(:qualified_word)           { word >> (str('.') >> word).maybe }
    rule(:word)                     { match('[a-zA-Z0-9_]').repeat(1) }
    rule(:eol)                      { (match('\n').repeat(1) | str(';')) >> space? }

    root(:program)

  end
end
