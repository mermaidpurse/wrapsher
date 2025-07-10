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
      the_elements = elements
      if the_elements.nil?
        the_elements = []
      end

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

    rule(subscript:{ receiver: subtree(:receiver), index: subtree(:index) }) do
      {
        fun_call: {
          name: 'at',
          fun_args: [receiver, index]
        }
      }
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

    rule(boolean_op: { left: subtree(:left), operator: simple(:operator), right: subtree(:right) }) do
      fn = case operator.to_s
           when 'and' then 'and'
           when 'or' then 'or'
           end
      {
        fun_call: {
          name: fn,
          fun_args: [left, right]
        }
      }
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

    rule(additive_op: { left: subtree(:left), operator: simple(:operator), right: subtree(:right) }) do
      fn = case operator.to_s
           when '+' then 'plus'
           when '-' then 'minus'
           end
     {
        fun_call: {
          name: fn,
          fun_args: [left, right]
        }
      }
    end

    rule(multiplicative_op: { left: subtree(:left), operator: simple(:operator), right: subtree(:right) }) do
      fn = case operator.to_s
           when '*' then 'times'
           when '/' then 'div'
           when '%' then 'mod'
           end
      {
        fun_call: {
          name: fn,
          fun_args: [left, right]
        }
      }
    end

    rule(postfix_chain: { receiver: subtree(:recv), calls: subtree(:chained_calls) }) do
      the_calls = chained_calls.is_a?(Array) ? chained_calls : [chained_calls]
      the_calls.reduce(recv) do |receiver, call|
        fun_call = call[:fun_call]
        fun_args = case fun_call[:fun_args]
                   when nil then []
                   when Array then fun_call[:fun_args]
                   else [fun_call[:fun_args]]
                   end
        {
          fun_call: {
            name: fun_call[:name],
            fun_args: [receiver, *fun_args]
          }
        }
      end
    end

  end
end
