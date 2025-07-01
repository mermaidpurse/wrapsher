require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

# TODO: loops, comments
module Wrapsher
  class Syntax < Parslet::Parser

    rule(:program)                  { statement.repeat }
    rule(:statement)                { (use_statement | meta_statement | module_statement | type_statement | fun_statement) >> eol }
    rule(:use_statement)            { use_version_statement | use_module_statement | use_feature_statement | use_external_statement }
    rule(:meta_statement)           { str('meta') >> space >> word.as(:meta_field) >> space >> string.as(:meta_data) }
    rule(:use_version_statement)    { str('use') >> space >> str('version') >> space >> version.as(:use_version) }
    rule(:use_module_statement)     { str('use') >> space >> str('module') >> space >> word.as(:use_module) }
    rule(:use_external_statement)   { str('use') >> space >> str('external') >> space >> word.as(:use_external) }
    rule(:use_feature_statement)    { str('use') >> space >> str('feature') >> space >> word.as(:use_feature) }
    rule(:module_statement)         { str('module') >> space >> word.as(:module) }
    rule(:type_statement)           { str('type') >> space >> word.as(:type) >> (space >> word.as(:store_type)).maybe }

    rule(:fun_statement)            { (signature.as(:signature) >> block.as(:body)).as(:fun_statement) }
    rule(:signature)                { word.as(:type) >> space >> word.as(:name) >> lparen >> arg_definitions.as(:arg_definitions) >> rparen }
    rule(:arg_definitions)          { (arg_definition >> (comma >> arg_definition).repeat).maybe }
    rule(:arg_definition)           { word.as(:type) >> space >> word.as(:name) }


    rule(:block)                    { lbrace >> whitespace? >> expressions >> whitespace? >> rbrace }
    rule(:expressions)              { (expression >> eol).repeat >> expression.maybe }
    rule(:expression)               { assignment | postfix_chain | conditional | fun_call | shellcode_call | boolean_not | secondary_op | primary_op | comparison | term }

    rule(:conditional)              { (str('if').as(:keyword_if) >> space >> expression.as(:condition) >> space? >> block.as(:then) >> (whitespace? >> str('else').as(:keyword_else) >> space >> block.as(:else)).maybe).as(:conditional) }

    rule(:assignment)               { (word.as(:var) >> space? >> str('=') >> space? >> expression.as(:rvalue)).as(:assignment) }
    rule(:shellcode_call)           { str('shell') >> space >> string.as(:shellcode) }
    rule(:postfix)                  { str('.') >> fun_call }
    rule(:postfix_chain)            { (term.as(:receiver) >> str('.').present? >> postfix.repeat.as(:calls)).as(:postfix_chain) }
    rule(:fun_call)                 { (word.as(:name) >> lparen >> space? >> fun_args.maybe.as(:fun_args) >> space? >> rparen).as(:fun_call) }
    rule(:fun_args)                 { expression >> (comma >> expression).repeat }

    rule(:primary_op)               { (term.as(:left) >> space? >> primary_operator.as(:operator) >> space? >> expression.as(:right)).as(:primary_op) }
    rule(:secondary_op)             { (term.as(:left) >> space? >> secondary_operator.as(:operator) >> space? >> expression.as(:right)).as(:secondary_op) }
    rule(:comparison)               { (term.as(:left) >> space? >> comparison_operator.as(:operator) >> space? >> expression.as(:right)).as(:comparison) }
    rule(:boolean_op)               { (term.as(:left) >> space? >> boolean_operator.as(:operator) >> space? >> expression.as(:right)).as(:boolean_op) }
    rule(:boolean_not)              { (((str('not') >> space >> space?) | str('!') >> space?) >> expression.as(:subject)).as(:boolean_not) }

    rule(:term)                     { lparen >> expression.as(:group) >> rparen | int_term | bool_term | string_term | var_ref }
    rule(:int_term)                 { (str('-').maybe >> match('[0-9]').repeat(1)).as(:int_term) >> space? }
    rule(:bool_term)                { (str('true') | str('false')).as(:bool_term) >> space? }
    rule(:string_term)              { string.as(:string_term) >> space? }
    rule(:var_ref)                  { word.as(:var_ref) >> space? }

    rule(:primary_operator)         { str('+') | str('-') }
    rule(:secondary_operator)       { str('*') | str('/') | str('%') }
    rule(:comparison_operator)      { str('==') | str('!=') | str('<') | str('>') | str('<=') | str('>=') }
    rule(:boolean_operator)         { str('and') | str('or') | str('xor') }

    rule(:version)                  { match('[0-9.]').repeat(1) }
    rule(:string)                   { triple_quoted | single_quoted }
    rule(:single_quoted)            { str('\'') >> char.repeat.as(:single_quoted) >> str('\'') }
    rule(:triple_quoted)            { str("'''") >> (str("'''").absent? >> any).repeat.as(:triple_quoted) >> str("'''") }

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
    rule(:word)                     { match('[a-zA-Z0-9_/]').repeat(1) }
    rule(:eol)                      { (match('\n').repeat(1) | str(';')) >> space? }

    root(:program)

  end
end
