require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

# TODO: loops, comments, errors
module Wrapsher
  class Syntax < Parslet::Parser

    rule(:program)                  { statement.repeat }
    rule(:statement)                { (use_statement | meta_statement | module_statement | type_statement | fun_statement) >> eol }
    rule(:use_statement)            { use_version_statement | use_module_statement | use_feature_statement | use_external_statement | use_global_statement }
    rule(:meta_statement)           { (str('meta') >> space >> word.as(:meta_field) >> space >> string.as(:meta_data)).as(:meta) }
    rule(:use_version_statement)    { str('use') >> space >> str('version') >> space >> version.as(:use_version) }
    rule(:use_module_statement)     { str('use') >> space >> str('module') >> space >> word.as(:use_module) }
    rule(:use_external_statement)   { str('use') >> space >> str('external') >> space >> word.as(:use_external) }
    rule(:use_feature_statement)    { str('use') >> space >> str('feature') >> space >> word.as(:use_feature) }
    rule(:use_global_statement)     { (str('use') >> space >> str('global') >> space >> word.as(:name) >> space >> term.as(:value)).as(:use_global) }
    rule(:module_statement)         { str('module') >> space >> word.as(:module) }
    rule(:type_statement)           { (str('type') >> space >> word.as(:name) >> space >> word.as(:store_type)).as(:type) }

    rule(:fun_statement)            { (signature.as(:signature) >> block.as(:body)).as(:fun_statement) }
    rule(:signature)                { word.as(:type) >> space >> word.as(:name) >> lparen >> arg_definitions.as(:arg_definitions) >> rparen >> space? }
    rule(:arg_definitions)          { (arg_definition >> (comma >> arg_definition).repeat).maybe }
    rule(:arg_definition)           { word.as(:type) >> space >> word.as(:name) }


    rule(:block)                    { lbrace >> whitespace? >> expressions >> whitespace? >> rbrace }
    rule(:expressions)              { (expression >> eol).repeat >> expression.maybe >> eol.maybe }
    rule(:conditional)              { (str('if').as(:keyword_if) >> space >> expression.as(:condition) >> space? >> block.as(:then) >> (whitespace? >> str('else').as(:keyword_else) >> space >> block.as(:else)).maybe).as(:conditional) }

    rule(:expression)               { (assignment | shellcode_call | conditional | boolean_op) }

    rule(:shellcode_call)           { str('shell') >> space >> string.as(:shellcode) }

    rule(:assignment)               { (word.as(:var) >> space? >> str('=') >> space? >> expression.as(:rvalue)).as(:assignment) >> space? }

    rule(:boolean_op)               { (comparison.as(:left) >> space? >> boolean_operator.as(:operator) >> space? >> comparison.as(:right)).as(:boolean_op) | comparison }
    rule(:comparison)               { (additive_op.as(:left) >> space? >> comparison_operator.as(:operator) >> space? >> additive_op.as(:right)).as(:comparison) | additive_op }
    rule(:additive_op)              { (multiplicative_op.as(:left) >> space? >> additive_operator.as(:operator) >> space? >> multiplicative_op.as(:right)).as(:additive_op) | multiplicative_op }
    rule(:multiplicative_op)        { (subscript.as(:left) >> space? >> multiplicative_operator.as(:operator) >> space? >> subscript.as(:right)).as(:multiplicative_op) | subscript }
    rule(:subscript)                { (chain.as(:receiver) >> lbracket >> expression.as(:index) >> rbracket).as(:subscript) | chain }
    rule(:chain)                    { postfix_chain | fun_call | boolean_not }
    rule(:boolean_not)              { ((str('not') >> space | str('!') >> space?) >> expression.as(:subject)).as(:boolean_not) | term }

    rule(:postfix)                  { str('.') >> fun_call }
    rule(:postfix_chain)            { (term.as(:receiver) >> str('.').present? >> postfix.repeat(1).as(:calls)).as(:postfix_chain) }
    rule(:fun_call)                 { (word.as(:name) >> lparen >> space? >> fun_args.maybe.as(:fun_args) >> space? >> rparen).as(:fun_call) }
    rule(:fun_args)                 { expression >> (comma >> expression).repeat }

    rule(:term)                     { group | int_term | bool_term | string_term | var_ref }
    rule(:group)                    { lparen >> expression.as(:group) >> rparen >> space? }
    rule(:int_term)                 { (str('-').maybe >> match('[0-9]').repeat(1)).as(:int_term) >> space? }
    rule(:bool_term)                { (str('true') | str('false')).as(:bool_term) >> space? }
    rule(:string_term)              { string.as(:string_term) >> space? }
    rule(:var_ref)                  { word.as(:var_ref) >> space? }

    rule(:additive_operator)        { str('+') | str('-') }
    rule(:multiplicative_operator)  { str('*') | str('/') | str('%') }
    rule(:comparison_operator)      { str('==') | str('!=') | str('<') | str('>') | str('<=') | str('>=') }
    rule(:boolean_operator)         { str('and') | str('or') }

    rule(:version)                  { match('[0-9.]').repeat(1) }
    rule(:string)                   { triple_quoted | single_quoted }
    rule(:single_quoted)            { str('\'') >> char.repeat.as(:single_quoted) >> str('\'') }
    rule(:triple_quoted)            { str("'''") >> (str("'''").absent? >> any).repeat.as(:triple_quoted) >> str("'''") }

    rule(:lbracket)                 { str('[') }
    rule(:rbracket)                 { str(']') }
    rule(:lbrace)                   { str('{') }
    rule(:rbrace)                   { str('}') }
    rule(:lparen)                   { str('(') }
    rule(:rparen)                   { str(')') }
    rule(:comma)                    { str(',') >> whitespace? }
    rule(:char)                     { str('\\\'') | (str('\'').absent? >> any) }
    rule(:space)                    { match(' ').repeat(1) }
    rule(:space?)                   { space.maybe }
    rule(:whitespace)               { match('\s').repeat(1) }
    rule(:whitespace?)              { whitespace.maybe }
    rule(:qualified_word)           { word >> (str('.') >> word).maybe }
    rule(:word)                     { match('[a-zA-Z0-9_/]').repeat(1) }
    rule(:eol)                      { (str(';') | match('\n')).repeat(1) >> whitespace? }

    root(:program)

  end
end
