# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2025 Mermaidpurse

require 'json'
require 'logger'
require 'parslet'
require 'wrapsher'

module Wrapsher
  # Syntax definition for Wrapsher
  # rubocop:disable Metrics/ClassLength, Layout/ExtraSpacing
  class Syntax < Parslet::Parser
    rule(:program)                  { (eol | comment >> str("\n") | statement).repeat }
    rule(:statement) do
      (use_statement | meta_statement | module_statement | type_statement | fun_statement) >> eol
    end
    rule(:use_statement) do
      use_version_statement | use_module_statement | use_feature_statement | use_external_statement | use_global_statement
    end
    rule(:meta_statement)           { (str('meta') >> space >> word.as(:meta_field) >> space >> string.as(:meta_data)).as(:meta) }
    rule(:use_version_statement)    { str('use') >> space >> str('version') >> space >> version.as(:use_version) }
    rule(:use_module_statement)     { str('use') >> space >> str('module') >> space >> word.as(:use_module) }
    rule(:use_external_statement)   { str('use') >> space >> str('external') >> space >> word.as(:use_external) }
    rule(:use_feature_statement)    { str('use') >> space >> str('feature') >> space >> word.as(:use_feature) }
    rule(:use_global_statement)     do
      (str('use') >> space >> str('global') >> space >> word.as(:name) >> space >> term.as(:value)).as(:use_global)
    end
    rule(:module_statement)         { str('module') >> space >> word.as(:module) }
    rule(:type_statement) do
      (str('type') >> space >> word.as(:name) >> space >>
        (word.as(:store_type) | list_term.as(:struct_spec))).as(:type)
    end

    rule(:fun_statement)            { (signature.as(:signature) >> block.as(:body)).as(:fun_statement) }
    rule(:signature)                do
      word.as(:type) >> space >> word.as(:name) >> lparen >> arg_definitions.as(:arg_definitions) >> rparen >> space?
    end
    rule(:arg_definitions)          { (arg_definition >> (comma >> arg_definition).repeat).maybe }
    rule(:arg_definition)           { word.as(:type) >> space >> word.as(:name) }

    rule(:block)                    { lbrace >> whitespace? >> expressions >> whitespace? >> rbrace >> space? }
    rule(:expressions)              { ((expression | comment) >> eol).repeat >> (expression | comment).maybe >> eol.maybe }
    rule(:throw_call)               { str('throw') >> space >> expression.as(:throw) }
    rule(:break_call)               { str('break').as(:break) }
    rule(:return_call)              { (str('return').as(:keyword_return) >> space >> expression.as(:return_value)).as(:return) }
    rule(:continue_call)            { str('continue').as(:continue) }
    rule(:while_loop)               do
      (str('while').as(:keyword_while) >> space >> expression.as(:condition) >> space? >> block.as(:loop_body)).as(:while)
    end

    rule(:conditional) do
      (str('if').as(:keyword_if) >> space >> expression.as(:condition) >>
        space? >> block.as(:then) >>
        (whitespace? >> (str('else') >> space >> str('if')).as(:keyword_elseif) >> space >> expression.as(:condition) >>
          space? >> block.as(:then)).repeat >>
        (whitespace? >> str('else').as(:keyword_else) >> space >>
          block.as(:else)).maybe).as(:conditional)
    end

    rule(:try_block) do
      (str('try').as(:keyword_try) >> space >> block.as(:try_body) >>
        whitespace? >> (str('catch').as(:keyword_catch) >> space >> word.as(:var) >>
          space? >> block.as(:catch_body)).as(:catch)).as(:try_block)
    end

    rule(:expression) do
      (assignment | break_call | continue_call | return_call | throw_call | shellcode_call |
        lambda | while_loop | conditional | try_block | boolean_op)
    end

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
    rule(:lambda_signature) do
      word.as(:type) >> space >> str('fun') >> space? >> lparen >> arg_definitions.as(:arg_definitions) >> paren >> space?
    end

    rule(:assignment) do
      (word.as(:var) >> space? >> str('=') >> space? >> expression.as(:rvalue)).as(:assignment) >> space?
    end

    rule(:boolean_op) do
      (comparison.as(:left) >>
        (space? >> boolean_operator.as(:operator) >>
          space? >> comparison.as(:right)).repeat(1)).as(:boolean_op) |
        comparison
    end

    rule(:comparison) do
      (pair.as(:left) >> space? >>
        comparison_operator.as(:operator) >> space? >>
        pair.as(:right)).as(:comparison) |
        pair
    end

    rule(:pair) do
      (additive_op.as(:key) >> space? >> colon >>
        space? >> additive_op.as(:value)).as(:pair) |
        additive_op
    end

    rule(:additive_op) do
      (multiplicative_op.as(:left) >>
        (space? >> additive_operator.as(:operator) >>
          space? >> multiplicative_op.as(:right)).repeat(1)).as(:additive_op) |
        multiplicative_op
    end

    rule(:multiplicative_op) do
      (boolean_not.as(:left) >>
        (space? >> multiplicative_operator.as(:operator) >>
          space? >> boolean_not.as(:right)).repeat(1)).as(:multiplicative_op) |
        boolean_not
    end

    rule(:boolean_not) do
      ((str('not') >> space | str('!') >> space?) >> chain.as(:subject)).as(:boolean_not) | chain
    end

    rule(:chain) do
      (term.as(:receiver) >>
        (postfix | subscript).repeat(1).as(:calls)).as(:chain) | term
    end

    rule(:subscript) do
      (lbracket >> expression.as(:index) >> rbracket).as(:subscript)
    end

    rule(:postfix) do
      str('.') >> fun_call.as(:postfix)
    end

    rule(:fun_call) do
      (word.as(:name) >> lparen >> space? >> fun_args.maybe.as(:fun_args) >> space? >> rparen).as(:fun_call)
    end
    rule(:fun_args)                 { expression >> (comma >> expression).repeat }

    rule(:term)                     { group | int_term | bool_term | string_term | empty_map_term | list_term | fun_call | var_ref }
    rule(:empty_map_term)           { (lbracket >> space? >> colon >> space? >> rbracket).as(:empty_map_term) >> space? }
    rule(:list_term)                do
      (lbracket.as(:lbracket) >> whitespace? >>
        (expression >> (comma >> expression).repeat).maybe.as(:elements)).as(:list_term) >>
        whitespace? >> rbracket >> space?
    end
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
    rule(:comment)                  { str('#') >> match('[^\n]').repeat.as(:comment) }

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
    rule(:word)                     { match('[a-zA-Z0-9_/]').repeat(1) }
    rule(:eol) do
      (str(';') | match('\n')).repeat(1) >> whitespace?
    end

    root(:program)
  end
  # rubocop:enable Metrics/ClassLength, Layout/ExtraSpacing
end
