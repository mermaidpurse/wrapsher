require 'logger'
require 'parslet'
require 'pry'

module Wrapsher
  class Transform < Parslet::Transform

    rule(postfix_chain: { receiver: subtree(:recv), calls: subtree(:chained_calls) }) do
      the_calls = chained_calls.is_a?(Array) ? chained_calls : [chained_calls]
      the_calls.reduce(recv) do |receiver, call|
        puts "receiver: #{receiver.inspect}"
        puts "call: #{call.inspect}"
        fun_call = call[:fun_call]
        fun_args = case fun_call[:fun_args]
                   when nil then []
                   when Array then fun_call[:fun_args]
                   else [fun_call[:fun_args]]
                   end
        {
          fun_call: {
            name: fun_call[:name],
            fun_args: [receiver, *fun_args],
          }
        }
      end
    end

  end
end
