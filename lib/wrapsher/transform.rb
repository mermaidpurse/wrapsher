require 'logger'
require 'parslet'
require 'pry'

module Wrapsher
  class TransformUtil
    class << self
      # This should maybe be done further
      # in the compiler, when there's more type
      # information and we can make this guess
      # based on the types of the expressions
      # in the list (because there could be
      # other ways of construcing a map. Somewhere, a list of pairs
      # from the parser needs to be promoted to
      # a map, and for now, that's here.
      #
      # Is this pair.from_kv(...)?
      def transformed_pair?(p)
        if p[:fun_call] && p[:fun_call][:name] == 'from_kv' &&
            p[:fun_call][:fun_args][0] == { var_ref: 'pair' }
          result = true
        else
          result = false
        end
        result
      end
    end
  end

  class Transform < Parslet::Transform

    rule(list_term: subtree(:elements)) do
      the_elements = [elements].compact.flatten

      is_map = false
      is_map = true if !the_elements.empty? && the_elements.all? { |p| TransformUtil.transformed_pair?(p) }

      new_list = {
        fun_call: {
          name: 'new',
          fun_args: [{var_ref: 'list'}]
        }
      }

      the_list = the_elements.reduce(new_list) do |acc, el|
        {
          fun_call: {
            name: 'push',
            fun_args: [acc, el]
          }
        }
      end

      if is_map
        {
          fun_call: {
            name: 'from_pairlist',
            fun_args: [
              { var_ref: 'map' },
              the_list
            ]
          }
        }
      else
        the_list
      end
    end

    rule(pair: subtree(:pair)) do
      {
        fun_call: {
          name: 'from_kv',
          fun_args: [
            { var_ref: 'pair' },
            pair[:key],
            pair[:value]
          ]
        }
      }
    end

    rule(empty_map_term: simple(:empty_map)) do
      {
        fun_call: {
          name: 'new',
          fun_args: [{ var_ref: 'map' }]
        }
      }
    end

    rule(conditional: subtree(:conditional)) do
      if conditional.is_a?(Array)
        last_conditional = conditional.pop
        line = last_conditional[%i[keyword_else keyword_elseif keyword_if].select { |k| last_conditional.key?(k) }]

        {
          conditional: conditional.reverse.reduce(last_conditional) do |otherwise, outer|
            if outer.key?(:keyword_else)
              raise Wrapsher::CompilationError, "else AND else if at line #{line[0]} col #{line[1]}"
            end

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
            store_type: store_type,
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
           when '!=' then ['eq', 'not']
           when '<=' then ['gt', 'not']
           when '>=' then ['lt', 'not']
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

    rule(throw: subtree(:e))  do
      {
        fun_call: {
          name: 'throw',
          fun_args: [e]
        }
      }
    end

    rule(single_quoted: subtree(:string)) {
      case string
      when Array
        if string.empty?
          { single_quoted: '' }
        end
      else
        { single_quoted: string }
      end
    }
  end
end
