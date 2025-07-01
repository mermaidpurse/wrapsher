require 'logger'
require 'parslet'
require 'pry'

module Wrapsher
  class Transform < Parslet::Transform

    rule(type: { name: simple(:name), store_type: simple(:store_type) }) do
      code = [
        {
          type: {
            name: name,
            store_type: store_type,
          }
        },
        {
          shellcode: { single_quoted: "_wshv_#{name}='type/#{name}:#{store_type}'" }
        }
      ]
      if store_type.to_s != 'builtin'
        # Create unsafe casts
        code << {
          fun_statement: {
            signature: {
              type: name.to_s,
              name: "_as_#{name}",
              arg_definitions: [{ type: store_type, name: 'v' }]
            },
            body: [
              {
                shellcode: { single_quoted: "_wsh_result='#{name}:${_wshv_v}'" }
              }
            ]
          }
        }
        code << {
          fun_statement: {
            signature: {
              type: store_type.to_s,
              name: "_as_#{store_type}",
              arg_definitions: [{ type: name, name: 'v' }]
            },
            body: [
              {
                shellcode: { single_quoted: "_wsh_result=\"${_wshv_v##{name}:}\"" }
              }
            ]
          }
        }
      end
      code
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
           when '<' then ['lt']
           when '>' then ['gt']
           when '<=' then ['gt', 'not']
           when '>=' then ['lt', 'not']
           end
      fn.reduce([left, right]) do |args, fun|
        { fun_call: { name: fun, fun_args: [left, right] } }
      end
    end

    rule(primary_op: { left: subtree(:left), operator: simple(:operator), right: subtree(:right) }) do
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

    rule(secondary_op: { left: subtree(:left), operator: simple(:operator), right: subtree(:right) }) do
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
