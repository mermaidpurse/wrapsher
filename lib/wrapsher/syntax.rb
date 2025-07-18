require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

module Wrapsher
  class Syntax < Parslet::Parser

    rule(:program)                  { (comment | statement).repeat }
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

    rule(:block)                    { lbrace >> whitespace? >> expressions >> whitespace? >> rbrace >> space? }
    rule(:expressions)              { (expression >> eol).repeat >> expression.maybe >> eol.maybe }
    rule(:throw_call)               { str('throw') >> space >> expression.as(:throw) }
    rule(:break_call)               { str('break').as(:break) }
    rule(:return_call)              { (str('return').as(:keyword_return) >> space >> expression.as(:return_value)).as(:return) }
    rule(:continue_call)            { str('continue').as(:continue) }
    rule(:while_loop)               { (str('while').as(:keyword_while) >> space >> expression.as(:condition) >> space? >> block.as(:loop_body)).as(:while) }
    rule(:conditional)              { (str('if').as(:keyword_if) >> space >> expression.as(:condition) >> space? >> block.as(:then) >> (whitespace? >> str('else').as(:keyword_else) >> space >> block.as(:else)).maybe).as(:conditional) }
    rule(:try_block)                { (str('try').as(:keyword_try) >> space >> block.as(:try_body) >> whitespace? >> (str('catch').as(:keyword_catch) >> space >> word.as(:var) >> space? >> block.as(:catch_body)).as(:catch)).as(:try_block) }

    rule(:expression)               { (assignment | break_call | continue_call | return_call | throw_call | shellcode_call | lambda | while_loop | conditional | try_block | pair) }

    rule(:shellcode_call)           { str('shell') >> space >> string.as(:shellcode) }

    rule(:lambda)                   do
      (
        (
          word.as(:type) >> space >>
          str('fun') >> space? >>
          lparen >> arg_definitions.as(:arg_definitions) >> rparen >> space?
        ).as(:signature) >>
        block.as(:body)
      ).as(:lambda)
    end
    rule(:lambda_signature)         { word.as(:type) >> space >> str('fun') >> space? >> lparen >> arg_definitions.as(:arg_definitions) >> paren >> space? }

    rule(:assignment)               { (word.as(:var) >> space? >> str('=') >> space? >> expression.as(:rvalue)).as(:assignment) >> space? }

    rule(:pair)                     { (boolean_op.as(:key) >> space? >> colon >> space? >> boolean_op.as(:value)).as(:pair) | boolean_op }
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

    rule(:term)                     { group | int_term | bool_term | string_term | empty_map_term | list_term | var_ref }
    rule(:empty_map_term)           { (lbracket >> space? >> colon >> space? >> rbracket).as(:empty_map_term) >> space? }
    rule(:list_term)                { lbracket >> whitespace? >> (expression >> (comma >> expression).repeat).maybe.as(:list_term) >> whitespace? >> rbracket >> space? }
    rule(:group)                    { lparen >> expression.as(:group) >> rparen >> space? }
    rule(:int_term)                 { (str('-').maybe >> match('[0-9]').repeat(1)).as(:int_term) >> space? }
    rule(:bool_term)                { (str('true') | str('false')).as(:bool_term) >> space? }
    rule(:string_term)              { string.as(:string_term) >> space? }
    rule(:var_ref)                  { word.as(:var_ref) >> space? }

    rule(:additive_operator)        { str('+') | str('-') }
    rule(:multiplicative_operator)  { str('*') | str('/') | str('%') }
    rule(:comparison_operator)      { str('==') | str('!=') | str('>=') | str('<=') | str('<') | str('>') }
    rule(:boolean_operator)         { str('and') | str('or') }

    rule(:version)                  { match('[0-9.]').repeat(1) }
    rule(:string)                   { triple_quoted | single_quoted }
    rule(:single_quoted) do
      str('\'') >>
      (
        match('[^\'\\\\]') |
        (str('\\') >> any) | (str('\'').absent? >> any)
      ).repeat.as(:single_quoted) >> str('\'')
    end
    rule(:triple_quoted)            { str("'''") >> (str("'''").absent? >> any).repeat.as(:triple_quoted) >> str("'''") }
    rule(:comment)                  { str('#') >> match('[^\n]').repeat.as(:comment) >> str("\n") }

    rule(:colon)                    { str(':') }
    rule(:lbracket)                 { str('[') }
    rule(:rbracket)                 { str(']') }
    rule(:lbrace)                   { str('{') }
    rule(:rbrace)                   { str('}') }
    rule(:lparen)                   { str('(') }
    rule(:rparen)                   { str(')') }
    rule(:comma)                    { str(',') >> whitespace? }
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
