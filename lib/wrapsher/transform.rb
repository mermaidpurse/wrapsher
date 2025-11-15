# frozen_string_literal: true

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2025 Mermaidpurse

require 'logger'
require 'parslet'
require 'pry'

module Wrapsher
  # Transforms parser tree into Wrapsher AST
  # understood by the code generator
  # rubocop:disable Metrics/ClassLength
  class Transform < Parslet::Transform
    rule(conditional: subtree(:conditional)) do
      if conditional.is_a?(Array)
        last_conditional = conditional.pop
        line = last_conditional[%i[keyword_else keyword_elseif keyword_if].select { |k| last_conditional.key?(k) }]

        {
          conditional: conditional.reverse.reduce(last_conditional) do |otherwise, outer|
            raise Wrapsher::CompilationError, "else AND else if at line #{line[0]} col #{line[1]}" if outer.key?(:keyword_else)

            if otherwise.key?(:then)
              otherwise[:keyword_if] = otherwise[:keyword_elseif]
              outer[:keyword_else] = otherwise[:keyword_elseif]
              outer[:else] = { conditional: otherwise }
            elsif otherwise.key?(:else)
              outer[:keyword_else] = otherwise[:keyword_else]
              outer[:else] = otherwise[:else]
            end
            outer
          end
        }
      else
        { conditional: conditional }
      end
    end

    rule(type: { name: simple(:name), store_type: simple(:store_type) }) do
      [
        {
          type: {
            name: name,
            store_type: store_type
          }
        }
      ]
    end

    rule(boolean_not: { subject: subtree(:subject) }) do
      {
        fun_call: {
          name: 'not',
          fun_args: [subject]
        }
      }
    end

    rule(boolean_op: subtree(:boolean_op)) do
      first_left = boolean_op.shift

      boolean_op.reduce(first_left[:left]) do |left, right|
        fn = case right[:operator].to_s
             when 'and' then 'and'
             when 'or' then 'or'
             end
        {
          fun_call: {
            name: fn,
            fun_args: [left, right[:right]]
          }
        }
      end
    end

    rule(comparison: { left: subtree(:left), operator: simple(:operator), right: subtree(:right) }) do
      fn = case operator.to_s
           when '==' then ['eq']
           when '!=' then %w[eq not]
           when '<=' then %w[gt not]
           when '>=' then %w[lt not]
           when '<' then ['lt']
           when '>' then ['gt']
           end
      fn.reduce([left, right]) do |args, fun|
        { fun_call: { name: fun, fun_args: args } }
      end
    end

    rule(additive_op: subtree(:additive_op)) do
      first_left = additive_op.shift

      additive_op.reduce(first_left[:left]) do |left, right|
        fn = case right[:operator].to_s
             when '+' then 'plus'
             when '-' then 'minus'
             end
        {
          fun_call: {
            name: fn,
            fun_args: [left, right[:right]]
          }
        }
      end
    end

    rule(multiplicative_op: subtree(:multiplicative_op)) do
      first_left = multiplicative_op.shift

      multiplicative_op.reduce(first_left[:left]) do |left, right|
        fn = case right[:operator].to_s
             when '*' then 'times'
             when '/' then 'div'
             when '%' then 'mod'
             end
        {
          fun_call: {
            name: fn,
            fun_args: [left, right[:right]]
          }
        }
      end
    end

    rule(chain: { receiver: subtree(:receiver), calls: subtree(:calls) }) do
      the_calls = [calls].flatten
      the_calls.reduce(receiver) do |recv, call|
        case call.keys.first
        when :subscript
          {
            fun_call: {
              name: 'at',
              fun_args: [recv, call[:subscript][:index]]
            }
          }
        when :postfix
          fun_name = call[:postfix][:fun_call][:name]
          fun_args = case call[:postfix][:fun_call][:fun_args]
                     when nil then []
                     when Array then call[:postfix][:fun_call][:fun_args]
                     else [call[:postfix][:fun_call][:fun_args]]
                     end
          {
            fun_call: {
              name: fun_name,
              fun_args: [recv, *fun_args]
            }
          }
        end
      end
    end

    rule(throw: subtree(:e)) do
      {
        fun_call: {
          name: 'throw',
          fun_args: [e]
        }
      }
    end

    rule(single_quoted: subtree(:string)) do
      case string
      when Array
        { single_quoted: '' } if string.empty?
      else
        { single_quoted: string }
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
