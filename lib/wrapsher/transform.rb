require 'logger'
require 'parslet'
require 'pry'

module Wrapsher
  class Transform < Parslet::Transform

    rule(boolean_not:{ subject: subtree(:subject) }) do
      {
        fun_call: {
          name: 'not',
          fun_args: [subject]
        }
      }
    end

    rule(boolean_op:{ left: subtree(:left), operator: simple(:operator), right: subtree(:right) }) do
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
           when '<' then ['lt']
           when '>' then ['gt']
           when '<=' then ['gt', 'not']
           when '>=' then ['lt', 'not']
           end
      fn.reduce([left, right]) do |args, fun|
        { fun_call: { name: fun, fun_args: [left, right] } }
      end
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
